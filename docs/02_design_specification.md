# 2. Design specification

## Topology

```text
                    pclk / preset_n                         wdt_clk / wdt_rst_n
                          |                                         |
                    +-----+------+                          +-------+--------+
 APB -------------> | fswwdt_regs| --cfg req/ack----------> | fswwdt_core    |
                    |  unlock    | --pet / intclr pulses--> |  counter       |
                    |  STAT mux  | <----- status 2FF -------|  window        |
                    +------------+                          |  error counter |
                                                            |  irq / reset   |
                                                            +-------+--------+
                                                                    |
                                                         wdt_irq, wdt_reset_req,
                                                         wdt_fail_ind
```

`fswwdt_top` is the only integration boundary. Everything under it is the IP.

## Module hierarchy

| Module | Role |
| --- | --- |
| `fswwdt_top` | Clock/reset sync, CDC hookup, pin mapping |
| `fswwdt_regs` | APB slave, register file, unlock FSM, config push |
| `fswwdt_cfg_cdc` | 4-phase multi-bit snapshot, latest write wins |
| `fswwdt_pulse_cdc` | Pet and interrupt-clear pulses, depth-3 queue |
| `fswwdt_core` | Window FSM |
| `fswwdt_counter` | Step or clear |
| `fswwdt_window` | Open-point decode |
| `fswwdt_error` | Saturating fault counter |
| `fswwdt_irq` | Sticky irq, 8-cycle reset pulse, sticky fail |
| `fswwdt_status_sync` | Return path, Gray error count |
| `fswwdt_sync` | Reset synchronizer and 2-flop vector |
| `fswwdt_sva` | Core assertions, compiled only with `FSWWDT_ASSERT` |

## Clocking

- `pclk` clocks the register file and the source side of every CDC.
- `wdt_clk` clocks the FSM, counter, irq, and reset pulse. It is unrelated to `pclk`. The bench default is 10 ns `pclk` and 100 ns `wdt_clk`. `+WDT_CLK_NS=<n>` changes the watchdog period.
- Config is not a bundle of 2-flop bits. The source holds the word stable, raises `req`, and the destination samples the word when the synchronized `req` is seen. `req` itself rises one source clock after the word is captured, so the sample is not racing the write.
- Pets are pulses. A toggle synchronizer would lose two pets that land in the same destination period, so the pet CDC counts up to three pending transfers.
- Status flags are single bits and use a plain 2-flop. The error count changes by one, so it is Gray-coded first.

## Reset

Both resets are asynchronous assert, synchronous deassert, through `fswwdt_reset_sync`.

| Reset | What it clears | What it does not clear |
| --- | --- | --- |
| `preset_n` | APB registers, unlock state, source side of the CDCs, status synchronizer flops | A core that is already out of IDLE |
| `wdt_rst_n` | FSM, count, error count, irq, reset pulse, fail flag | The register file |

After `preset_n` is released, the first observed rising edge of synchronized `wdt_rst_n` only arms the reload detector. It does not push the freshly cleared registers into the running core. A later 0-to-1 on `wdt_rst_n`, while `preset_n` stays high, does push. That is how a watchdog-domain reset reapplies `CTRL` without letting a bus reset turn the dog off.

Power-on reset in the SoC should assert both pins. The bench `do_reset` task does that.

## FSM

```text
IDLE -- EN=1, window off --> OPEN
IDLE -- EN=1, window on  --> CLOSED
CLOSED -- count reaches open point --> OPEN
CLOSED -- pet --> fault, stay CLOSED or go RESET
OPEN -- pet --> reload, CLOSED if window mode else OPEN
OPEN -- count reaches timeout --> fault, CLOSED/OPEN or RESET
RESET -- pulse finished --> CLOSED or OPEN
any -- EN=0 --> IDLE
```

The timeout period is `TO_VAL` cycles of `wdt_clk` spent in CLOSED+OPEN. With a 50% window, the first half of those cycles is CLOSED and the second half is OPEN. A pet in OPEN is legal even on the last open count. The next count would be the timeout, and that cycle is the late fault if no pet came.

RESET holds the count at 0 for the reset pulse so a second timeout does not stack inside the pulse. When the pulse ends, a new window starts and the error count is still at the threshold, so another miss will reset again until good pets decrement it.

## Coding choices

- `always_ff` / `always_comb`, active-low async reset, no latches, no delays, no `logic` inferred from a missing declaration (`default_nettype none`).
- Synchronizer flops are marked `ASYNC_REG` so Genus keeps them close and does not retiming them.
- Assertions and the reset-image self-check are under `FSWWDT_ASSERT`, so a synthesis file list that does not set the macro does not need `fswwdt_sva`.
- Minimum timeout is 2 and minimum threshold is 1, clamped on the write so the readback matches the hardware behavior.
