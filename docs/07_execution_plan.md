# 7. Execution plan

The RTL, UVM bench, assertions, and scripts in this repository are the implementation of the steps below. What is left on the Cadence host is compile, debug, coverage merge, and signoff. The plan is written as a single engineer taking the block from a blank spec to a review package. About four weeks.

## Week 1 — specification

**Day 1.** Read the safety need with the integrator. Write down who pets the dog, how often, and what `wdt_reset_req` is connected to. Decide the two clocks and that `wdt_clk` is always on. Output: the port list and the "preset must not disable a running dog" rule.

**Day 2.** Freeze the register map, the service key, the unlock sequence, and the window fractions. Call out the clamps (timeout at least 2, threshold at least 1) so verification does not treat them as don't-cares.

**Day 3.** Draw the FSM (IDLE, CLOSED, OPEN, RESET) and the CDC plan: req/ack for the config word, a queued pulse for the pet, 2-flop plus Gray for status. Review it with a second designer before coding. This is the cheapest day to change the architecture.

**Day 4.** Write the test plan in the same words as the spec: one test per fault type, plus reset and clock rows. Name the scoreboard's job (registers and `PSLVERR`) separately from the sequences' job (pin timing).

**Day 5.** Review. Fix anything that says "software will never do that" unless the register lock actually makes it impossible.

## Week 2 — RTL

**Day 6.** Package, reset sync, 2-flop, config CDC, pulse CDC. Simulate the CDCs alone if the full core is not ready: one push, two pushes back-to-back, a pulse during destination reset.

**Day 7.** Register file and unlock FSM. Directed APB only. Check lock, both keys, a broken key sequence, and the clamps.

**Day 8.** Counter, window decode, error counter, irq pulse. Keep them free of the APB so the FSM can be read on one page.

**Day 9.** Core FSM and top-level hookup, including the "reload config only on a real `wdt_rst_n` release" rule. Run `make smoke`.

**Day 10.** Add `fswwdt_sva` and clean the assertion failures. Do not delete an assertion to go green. If `a_reset_pulse_width` fails, the pulse counter is wrong.

## Week 3 — UVM

**Day 11.** Interface, driver, monitor, agent, `tb_top`. A single write/read of `ID` from a sequence.

**Day 12.** Register model and scoreboard. Run `fswwdt_reg_test` until the model and the RTL agree on every `PSLVERR`.

**Day 13.** `arm()`, `wait_running`, classic pet, timeout, early, late. These fail first because of CDC latency. Fix the wait, not the timeout value, until the wait matches the spec.

**Day 14.** Interrupt, threshold-1 reset, threshold-3 early pets, bad key.

**Day 15.** Reset and clock tests: power-on, warm, async, sync, clock stop, frequency plusarg, preset-only survival, reset during an active irq.

## Week 4 — closure

**Day 16.** Coverage model. Run `fswwdt_cov_fill_test` and the random test. Merge.

**Day 17.** Close functional holes. Inspect uncovered FSM arcs from the SVA cover properties. Write one new directed sequence per hole. Do not waive a hole you can hit with a pet.

**Day 18.** Code-coverage pass in IMC. Unreachable `default` branches in full case statements can be waived. A missing toggle on `wdt_reset_req` cannot.

**Day 19.** Re-run the whole regression at `WDT_CLK_NS=100` and `WDT_CLK_NS=40`. Both must pass. Skim every log for assertion messages, not only `UVM_ERROR`.

**Day 20.** Signoff package: spec, register map, test plan, regression log summary, merged coverage, open waivers, and the integration note that `wdt_clk` must not stop and that `wdt_reset_req` should come back as `wdt_rst_n`.

## Exit criteria

- `make smoke` prints `SMOKE PASSED`.
- `make regress` prints `PASS` for every test at the default period and at 40 ns.
- Merged `cg_apb`, `cg_fault`, and `cg_evt` are at 100%, or each miss has a written waiver.
- No assertion failures in the logs.
- A second engineer can arm the core from the register section of `docs/01_project_understanding.md` without reading the RTL.
