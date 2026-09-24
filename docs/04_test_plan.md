# 4. Test plan

All of these are in `uvm/fswwdt_sequences.sv` and are launched by the matching class in `uvm/fswwdt_tests.sv`. `make regress` runs them. `sim/tb_rtl_smoke.sv` is the UVM-free bring-up test: ID, a short classic timeout, irq, and the reset pulse.

Pass means the sequence's checks produced no `UVM_ERROR` and the scoreboard accepted every APB access.

## Functional

| Test | What it proves |
| --- | --- |
| `fswwdt_reg_test` | Reset values, `TO_VAL` clamp to 2, threshold clamp to 1, CFG/CTRL readback, lock rejects CFG, a bad unlock does not open, the two-key sequence does, wrong pet key sets `BAD_SRV`, `INTCLR` clears it, ID writes and unaligned or unmapped addresses return `PSLVERR` |
| `fswwdt_basic_test` | Classic mode. Three pets inside a 40-count window do not raise irq. Stopping the pets does |
| `fswwdt_window_test` | 25% window, pet after 24 counts is legal (`EARLY_ERR` and `TO_ERR` stay 0). The following miss still times out, so the pet really reloaded the counter |
| `fswwdt_timeout_test` | No pet. Irq stays low for the first 8 counts, then `TO_ERR` and `wdt_irq` |
| `fswwdt_early_test` | Window mode, pet immediately after `RUNNING`. `EARLY_ERR` and irq, no reset (threshold is 5) |
| `fswwdt_late_test` | Window mode, no pet. The flag that sets is `TO_ERR`, not `EARLY_ERR` |
| `fswwdt_irq_test` | `IRQ_EN=0` still sets `TO_ERR` and does not drive the pin. After a fresh arm with `IRQ_EN=1`, the pin asserts. `INTCLR[0]` drops it |
| `fswwdt_reset_test` | Threshold 1: the first timeout pulses `wdt_reset_req` and sticks `wdt_fail_ind`. Threshold 3 with three early pets: irq only on the first two, reset on the third |
| `fswwdt_err_inject_test` | `32'hDEADBEEF` sets `BAD_SRV` and does not prevent the timeout |
| `fswwdt_rand_test` | 80 constrained random APB accesses. The scoreboard is the checker |
| `fswwdt_cov_fill_test` | All four `WIN_SEL` values take an early pet and a timeout. Also samples the large timeout bin and a reset |

## Clock and reset

| Test | What it proves |
| --- | --- |
| `fswwdt_por_test` | After both resets, irq and reset pins are low and `RUNNING` is 0 |
| `fswwdt_warm_reset_test` | Enable, then assert both resets. Pins and `RUNNING` clear, `CTRL` is the reset value, and a new arm still times out |
| `fswwdt_async_reset_test` | Resets fall 3 ns after a `pclk` edge, in the middle of the cycle, while irq is already high. Pins clear before the next aligned edge |
| `fswwdt_sync_reset_test` | Resets are assigned on the clock edge. Pins clear |
| `fswwdt_clk_stop_test` | After `RUNNING`, gate `wdt_clk` for 400 `pclk`s, longer than the 20-count timeout. No irq while the clock is stopped. Irq arrives after the clock restarts |
| `fswwdt_freq_test` | Measures `wdt_clk`, arms a 32-count classic watchdog, and checks the irq delay is between 16 and 80 measured periods. Run it again with `make regress PERIOD=40` or `+WDT_CLK_NS=40` |
| `fswwdt_reset_during_run_test` | `preset_n` alone clears `CTRL.EN` and leaves `STAT.RUNNING` set. A following `wdt_rst_n` stops the core because the reloaded `CTRL` is disabled. A fresh arm still times out |
| `fswwdt_reset_during_to_test` | Irq is high, `wdt_rst_n` clears it, release reloads `EN=1`, and a second timeout occurs |

## Corner cases covered inside those tests

- Timeout programmed as 0 reads back as 2. Threshold programmed as 0 reads back as 1.
- Pet during the closed region, pet during the open region, pet with the wrong key, pet after the window has already been missed.
- Lock held across a rejected write. Unlock step 1 aborted by the wrong second key.
- Reset while idle, while running, and while the irq is already asserted.
- Service-queue overflow (`STAT[10]`) is implemented and not forced; three back-to-back pets are absorbed by the CDC queue. Overflow is a stress case for a later directed test if software can issue pets faster than `wdt_clk` for more than three queued handshakes.

## Debug when a test fails

1. Open `sim/logs/<test>.log` and find the first `UVM_ERROR`.
2. Re-run that test with `make waves TEST=<test>` and open `fswwdt.vcd`, or use `xrun -gui`.
3. In SimVision, look at `dut.u_core.state`, `dut.u_core.count`, `dut.u_core.err_cnt`, and the APB access that the message names.
4. If the message is `REG`, the register model and `fswwdt_regs.sv` disagree. Fix the RTL or the model so they describe the same rule. Do not weaken the scoreboard to hide it.
