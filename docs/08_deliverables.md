# 8. Deliverables

```text
Vanithtask/
  README.md
  docs/
    01_project_understanding.md
    02_design_specification.md
    03_verification_architecture.md
    04_test_plan.md
    05_functional_coverage_and_assertions.md
    06_cadence_flow.md
    07_execution_plan.md
    08_deliverables.md
  rtl/
    fswwdt_pkg.sv            constants, register addresses, Gray helpers
    fswwdt_sync.sv           reset sync, 2-flop
    fswwdt_cfg_cdc.sv        config handshake
    fswwdt_pulse_cdc.sv      pet and clear pulses
    fswwdt_regs.sv           APB and lock/unlock
    fswwdt_counter.sv
    fswwdt_window.sv
    fswwdt_error.sv
    fswwdt_irq.sv
    fswwdt_core.sv           FSM
    fswwdt_status_sync.sv
    fswwdt_top.sv
  sva/
    fswwdt_sva.sv
  uvm/
    fswwdt_if.sv
    fswwdt_uvm_pkg.sv
    fswwdt_seq_item.sv
    fswwdt_wdt_item.sv
    fswwdt_driver.sv
    fswwdt_monitor.sv
    fswwdt_sequencer.sv
    fswwdt_agent.sv
    fswwdt_wdt_monitor.sv
    fswwdt_wdt_agent.sv
    fswwdt_reg_model.sv
    fswwdt_scoreboard.sv
    fswwdt_coverage.sv
    fswwdt_env.sv
    fswwdt_sequences.sv
    fswwdt_base_test.sv
    fswwdt_tests.sv
    tb_top.sv
  sim/
    Makefile
    run_regress.sh
    filelist_rtl.f          synthesis / no assertions
    filelist_uvm.f
    filelist_smoke.f
    tb_rtl_smoke.sv
    cov.ccf
    cov_merge.tcl
```

UVM hierarchy at run time:

```text
uvm_test_top
  env
    apb (fswwdt_agent, active)
      sqr
      drv
      mon
    wdt (fswwdt_wdt_agent, passive)
      mon
    sb
    cov
```

## Bring-up order

1. `cd sim && make smoke`
2. `make sim TEST=fswwdt_reg_test`
3. `make sim TEST=fswwdt_basic_test`
4. `make regress`
5. `make merge`

## Integration checklist

- Tie `wdt_clk` to an always-on clock.
- Assert `preset_n` and `wdt_rst_n` together at power-on.
- Synchronize `wdt_irq` into the CPU interrupt domain if that domain is not `wdt_clk`.
- Stretch or directly use `wdt_reset_req`, and feed the resulting system reset back to `wdt_rst_n`.
- Boot software writes `CFG` and `ERRCNT`, then `CTRL` with `EN`, `WIN_EN`, `IRQ_EN`, `RST_EN`, and `LOCK` in one write if the lock should stick before the application runs.
- The application pets with `SRV = 32'h5A5A_A5A5` only while `STAT.WIN_OPEN` is expected, or on a schedule that falls in that window.
