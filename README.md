# FSWWDT

Fail-safe window watchdog in SystemVerilog, with a UVM bench and a Cadence Xcelium flow.

The counter runs on its own clock. Software must pet it inside an open window. An early pet and a missed pet are both faults. Enough faults pulse a reset request that the CPU cannot turn off once the registers are locked.

## Start here

| Question | Where |
| --- | --- |
| What the block does, ports, registers | [docs/01_project_understanding.md](docs/01_project_understanding.md) |
| FSM, clocks, resets, module split | [docs/02_design_specification.md](docs/02_design_specification.md) |
| UVM components | [docs/03_verification_architecture.md](docs/03_verification_architecture.md) |
| Which test covers which case | [docs/04_test_plan.md](docs/04_test_plan.md) |
| Covergroups and SVA | [docs/05_functional_coverage_and_assertions.md](docs/05_functional_coverage_and_assertions.md) |
| `xrun`, SimVision, IMC | [docs/06_cadence_flow.md](docs/06_cadence_flow.md) |
| Day-by-day through signoff | [docs/07_execution_plan.md](docs/07_execution_plan.md) |
| Tree and bring-up order | [docs/08_deliverables.md](docs/08_deliverables.md) |

## Run

On a Cadence Linux host, from `sim/`:

```bash
make smoke
make sim TEST=fswwdt_basic_test
make regress
```

`pclk` is 10 ns. `wdt_clk` defaults to 100 ns. `make sim TEST=fswwdt_freq_test PERIOD=40` runs the same test on a faster watchdog clock.

Xcelium is not on this Windows machine, so these tests have not been executed here. The first command to trust is `make smoke`, then `fswwdt_reg_test`.

## Pet sequence

1. Write `CFG` at `0x04`: bits `[15:0]` are the timeout in `wdt_clk` ticks (minimum 2), bits `[17:16]` select the open point (00 = 50%, 01 = 25%, 10 = 75%, 11 = 12.5%).
2. Write `ERRCNT` at `0x10`: bits `[15:8]` are the fault threshold (minimum 1, reset value 3).
3. Write `CTRL` at `0x00`: set EN, and WIN_EN if the open window should be enforced. IRQ_EN and RST_EN come out of reset already set. Set LOCK in the same write if later code must not disable the dog.
4. Poll `STAT` bit 0 (`RUNNING`) at `0x0C`.
5. Write `32'h5A5A_A5A5` to `SRV` at `0x08` only while the window is open.
6. On irq, fix the software fault and write `INTCLR` bit 0. A good later pet decrements the error count by one.

Remote: https://github.com/raghuyt/VanithaTask.git
