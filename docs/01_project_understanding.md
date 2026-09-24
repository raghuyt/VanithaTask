# 1. Project understanding

## What this block is

FSWWDT is a fail-safe window watchdog for an SoC subsystem. Software must pet it by writing a key into `SRV`. In classic mode any pet before the timeout is legal. In window mode the pet is legal only after the open point and before the timeout.

A pet that arrives too early means the software is looping faster than the designed schedule, often a stuck task that still executes the pet. A pet that never arrives means the software is hung. Either event is a fault.

## Use cases

- A CPU subsystem that must be reset if application software stops scheduling.
- An automotive or industrial safety path where a simple timeout watchdog is not enough, because a tight fault loop can still kick a classic watchdog.
- A boot flow that configures the window, enables the counter, then locks the registers so later software cannot turn the dog off.

## Fail-safe rules implemented here

- The counter runs on `wdt_clk`, not `pclk`. If the CPU bus clock stops after the dog is enabled, pets stop and the counter still reaches the timeout.
- `wdt_clk` itself must be an always-on clock. If that clock stops, the counter stops and will not save the system. That is an integration requirement, and `fswwdt_clk_stop_test` locks it in.
- `preset_n` resets only the APB register file. A watchdog that is already running keeps running, so a bus reset caused by the hung CPU cannot silence it. `CTRL` reads back as reset data after that event; `STAT.RUNNING` is the truth.
- `wdt_rst_n` resets the counter domain. On a real release of that reset, the register file is pushed again so the core matches `CTRL`.
- Once `LOCK` is set, `CTRL`, `CFG`, and `ERRCNT` reject writes with `PSLVERR` until software writes `UNLOCK` key 1 (`32'hC3C3_3C3C`) and then key 2 (`32'h3C3C_C3C3`). The unlock is consumed by the next protected write.
- The pet is not a write of `1`. It is a write of `32'h5A5A_A5A5`. A random store is unlikely to reload the counter. A wrong key sets `STAT.BAD_SRV` and does not reload.
- Faults accumulate. A good pet decrements the error count by one. Reaching the threshold with `RST_EN` pulses `wdt_reset_req` for 8 `wdt_clk` cycles and sticks `wdt_fail_ind`.

## Data flow

1. Software programs `CFG` (timeout, window select) and `ERRCNT` (threshold), then sets `CTRL.EN`.
2. The register file pushes a 32-bit snapshot across a req/ack CDC into the `wdt_clk` domain.
3. The core leaves IDLE. In window mode it counts in CLOSED, then OPEN. A pet is a one-cycle pulse in the watchdog domain, carried by a queueing pulse CDC so back-to-back APB writes are not collapsed.
4. A legal pet reloads the count and decrements the error count. An early pet or a timeout increments it.
5. Below the threshold the core raises `wdt_irq` (if enabled) and starts a new window. At the threshold it also pulses `wdt_reset_req`.
6. Status bits return to `pclk` through 2-flop synchronizers. The error count is Gray-coded because it moves by +1 or -1. A disable or reset clears it in one step, so `ERRCNT[7:0]` can be incoherent for two `pclk` cycles at that moment.

## Ports

| Port | Direction | Domain | Role |
| --- | --- | --- | --- |
| `pclk`, `preset_n` | in | APB | Register clock, async active-low reset |
| `psel`, `penable`, `pwrite`, `paddr`, `pwdata` | in | APB | Zero-wait APB |
| `prdata`, `pready`, `pslverr` | out | APB | Read data, always ready, slave error |
| `wdt_clk`, `wdt_rst_n` | in | WDT | Counter clock and its async reset |
| `wdt_irq` | out | WDT | Sticky interrupt level |
| `wdt_reset_req` | out | WDT | 8-cycle fail-safe reset request |
| `wdt_fail_ind` | out | WDT | Sticky fail flag |

`wdt_irq` and `wdt_reset_req` are synchronous to `wdt_clk`. The interrupt fabric and the reset controller synchronize or stretch them. The reset controller should assert `wdt_rst_n` as part of taking the reset, otherwise the core reloads `CTRL` and starts again.

## Registers

Byte address, 32-bit, word aligned. Any other address returns `PSLVERR`.

| Offset | Name | Access | Reset | Bits |
| --- | --- | --- | --- | --- |
| `0x00` | CTRL | RW, lockable | `0x0000000C` | `[0]` EN, `[1]` WIN_EN, `[2]` IRQ_EN, `[3]` RST_EN, `[4]` LOCK |
| `0x04` | CFG | RW, lockable | `0x00000100` | `[15:0]` TO_VAL (min 2), `[17:16]` WIN_SEL |
| `0x08` | SRV | WO | — | Write `32'h5A5A_A5A5` to pet |
| `0x0C` | STAT | RO | `0` | See status bits below |
| `0x10` | ERRCNT | RW thresh / RO count | thresh 3 | `[7:0]` count, `[15:8]` threshold (min 1) |
| `0x14` | UNLOCK | WO | — | Key 1 then key 2 |
| `0x18` | INTCLR | WO | — | `[0]` clear irq and fault flags, `[1]` clear fail / reset sticky |
| `0x1C` | ID | RO | `32'h46535754` | ASCII `FSWT`. Writes return `PSLVERR` |

`WIN_SEL`: `00` open at 50% of `TO_VAL`, `01` at 25%, `10` at 75%, `11` at 12.5%. Integer divide. The open point is clamped so both the closed region and the open region are at least one count.

Status bits:

| Bit | Name | Meaning |
| --- | --- | --- |
| 0 | RUNNING | Core is not in IDLE |
| 1 | WIN_OPEN | Core is in OPEN |
| 2 | TO_ERR | Sticky timeout |
| 3 | EARLY_ERR | Sticky early pet |
| 4 | IRQ_PEND | Interrupt sticky, follows `wdt_irq` after CDC |
| 5 | RST_PEND | Fail sticky |
| 6 | BAD_SRV | Wrong service key, `pclk` domain |
| 7 | LOCK | Lock bit, so software can read it back |
| 8 | FAIL | `wdt_fail_ind` after CDC |
| 9 | UNLOCK_OPEN | Unlock sequence is armed for one protected write |
| 10 | SRV_LOST | Pulse CDC dropped a pet because 3 were already queued |
| 31:11 | — | Read as 0 |

IRQ_EN and RST_EN reset to 1. EN resets to 0. The safe default is "armed the moment software enables it", not "silent until someone remembers the interrupt enables".

## Error handling

- Wrong service key: `BAD_SRV`, counter unchanged.
- Early pet (`WIN_EN` and state CLOSED): error +1, reload, `EARLY_ERR`, irq if `IRQ_EN`.
- Timeout at the end of OPEN: error +1, reload, `TO_ERR`, irq if `IRQ_EN`.
- If the incremented count would reach the threshold and `RST_EN` is set: also enter RESET, pulse `wdt_reset_req`, set `wdt_fail_ind`.
- Legal pet: error -1 if it was non-zero, reload, CLOSED again when window mode is on.
- `INTCLR[0]` clears the irq and the two fault flags. `INTCLR[1]` clears the fail sticky. It does not cut a reset pulse short.
- Disabling `EN` clears the count, the error count, and the output pins. Lock is what stops untrusted software from doing that.
