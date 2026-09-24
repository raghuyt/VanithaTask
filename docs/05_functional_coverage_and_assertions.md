# 5. Functional coverage and assertions

## Covergroups

Implemented in `uvm/fswwdt_coverage.sv`.

`cg_apb`

- `cp_addr`: the eight registers, plus one illegal bin
- `cp_write`: read and write
- `cp_slverr`: accepted access and `PSLVERR`
- `cp_win_sel`: 50, 25, 75, 12.5 percent, sampled only on an accepted `CFG` write
- `cp_to_range`: 2–31, 32–255, 256 and above, same `CFG` sample
- `cp_en`, `cp_win_en`: sampled only on an accepted `CTRL` write
- `cx_addr_write`: address crossed with read/write

`cg_fault`

- `cp_win_sel` crossed with early vs timeout
- Sampled when a `STAT` read shows `EARLY_ERR` or `TO_ERR`, using the last accepted `WIN_SEL`

`cg_evt`

- At least one irq rise and one reset rise

## Targets

| Group | Target | How it closes |
| --- | --- | --- |
| `cg_apb` | 100% | `fswwdt_reg_test` hits every address, both directions, `PSLVERR`, enable on and off. `fswwdt_cov_fill_test` hits all four window selects and the large timeout bin. Merge the tests |
| `cg_fault` cross | 100% | `fswwdt_cov_fill_test` does early and timeout for each `WIN_SEL` |
| `cg_evt` | 100% | Any irq test plus `fswwdt_reset_test` or the reset leg of cov fill |

Per-test coverage will not be 100%. Signoff is the merged database from `make regress` then `make merge`.

Code coverage (block, expression, toggle, FSM) is collected with `sim/cov.ccf` as supporting evidence. The FSM cover properties in `fswwdt_sva` (`c_arc_*`) should also be hit: CLOSED to OPEN, early, timeout, reset, legal pet. A hole in those means a directed test never exercised that arc, even if a covergroup looks full.

## Closure

1. Run `make regress` so each test has `-covtest <name>`.
2. `make merge` (`imc -exec cov_merge.tcl`).
3. Read `docs/cov_functional.txt`.
4. For each hole, add a directed pet or a read of `STAT` at the moment the flag is set. Do not exclude a bin that the specification says is reachable.
5. Waive only integration-unreachable code, with a one-line reason in the review notes. `STAT[10]` (service overflow) is reachable but not hit by the current regression; treat it as an open hole until a test queues four pets inside one `wdt_clk` period, or waive it with that sentence if the software contract forbids it.

## Assertions

`sva/fswwdt_sva.sv`, instantiated in `fswwdt_core` when `+define+FSWWDT_ASSERT` is set. All are clocked by `wdt_clk` and disabled while `wdt` reset is low.

| Name | Check |
| --- | --- |
| `a_step_clear_mutex` | The FSM never steps and clears on the same cycle |
| `a_idle_count` | Count is 0 in IDLE |
| `a_leave_idle` | `EN` takes the FSM out of IDLE |
| `a_closed_below_thr` | CLOSED means `count < win_thr` once the threshold is stable |
| `a_open_at_or_past_thr` | Window-mode OPEN means `count >= win_thr` |
| `a_early_not_with_valid` / `a_early_not_with_timeout` | A cycle is only one of early, legal pet, or timeout |
| `a_timeout_flag` / `a_early_flag` | The matching sticky flag sets |
| `a_irq_on_fault` | `do_irq` raises `wdt_irq` |
| `a_reset_on_fatal` | `do_reset` raises `wdt_reset_req` |
| `a_reset_pulse_width` | The pulse stays high for `RST_PULSE_W` (8) cycles |
| `a_err_inc` / `a_err_dec` | Fault adds one, a legal pet subtracts one |
| `a_valid_reloads` | A legal pet clears the count |

APB protocol assertions sit on `fswwdt_if`: `PENABLE` implies `PSEL`, a setup phase is followed by an access phase, and `PSLVERR` is only high in the access phase.

`$stable(win_thr)` and `$stable(win_en)` gate the window checks so a configuration update in the same cycle is not reported as a window bug. A real window violation with a stable configuration still fails.
