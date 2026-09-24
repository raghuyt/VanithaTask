# 3. Verification architecture

The bench is black-box at the APB pins and the three watchdog outputs. Scoreboard checks are on the register file, which is fully visible on APB. Window timing checks live in the directed sequences because the count itself is not a register. `fswwdt_sva` is bound inside the core and checks the count, the window, and the pulse width directly.

## Components

```text
tb_top
  fswwdt_top (DUT)
  fswwdt_if
  uvm_test_top (fswwdt_*_test)
    env
      apb agent (active)
        sequencer <- sequences
        driver    -> PSEL/PENABLE/PADDR/PWDATA
        monitor   -> analysis port
      wdt agent (passive)
        monitor   -> irq / reset / fail rises
      scoreboard  (register model + PSLVERR)
      coverage
```

`tb_top` owns both clocks. `wdt_clk_en` on the interface is sampled on the falling edge of the raw watchdog clock and then AND-gates it, so the clock-stop test does not glitch the clock and does not add a DUT pin.

## Why the pieces are split this way

- One active APB agent is the software model. The sequencer is the only thing that starts bus transactions.
- The watchdog outputs are not an APB transaction, so they are a second, passive agent. The sequence still looks at the virtual interface when it needs to wait for a pin. The monitor exists so coverage and the scoreboard see the same edges the tests wait on.
- The scoreboard's `fswwdt_reg_model` repeats the lock, unlock, clamp, and `PSLVERR` rules from `fswwdt_regs.sv`. Every monitored write updates it. Every monitored read of `CTRL`, `CFG`, `ID`, and the bus-domain status bits is compared. `STAT[5:0]` and `STAT[8]` are live watchdog state and are checked by the sequences, not by a bit-exact prediction, because they cross clock domains.
- On `negedge preset_n` the model returns to the register reset values. That is the same moment the RTL register file clears.
- Functional coverage subscribes to the same analysis ports. It does not drive anything.

## Sequences and tests

`fswwdt_base_test` holds reset low, releases both resets, then calls `run_test_seq()`. Each test starts one sequence on `env.apb.sqr`. The base sequence has the APB tasks, `arm()`, and the pin waits.

`run_test()` is started from `tb_top`. Passing tests print `TEST PASSED`. Any `UVM_ERROR` or `UVM_FATAL` prints `TEST FAILED`.

## File map

| Path | Contents |
| --- | --- |
| `uvm/fswwdt_if.sv` | Pins plus APB protocol assertions |
| `uvm/fswwdt_uvm_pkg.sv` | Package that includes every class |
| `uvm/fswwdt_seq_item.sv` | APB transaction |
| `uvm/fswwdt_wdt_item.sv` | Output event |
| `uvm/fswwdt_driver.sv` | Setup then access, zero wait |
| `uvm/fswwdt_monitor.sv` | Samples the access phase |
| `uvm/fswwdt_sequencer.sv` | `uvm_sequencer` of the APB item |
| `uvm/fswwdt_agent.sv` | Active APB agent |
| `uvm/fswwdt_wdt_monitor.sv` / `fswwdt_wdt_agent.sv` | Passive output agent |
| `uvm/fswwdt_reg_model.sv` | Register predictor |
| `uvm/fswwdt_scoreboard.sv` | Compare |
| `uvm/fswwdt_coverage.sv` | Covergroups |
| `uvm/fswwdt_env.sv` | Wiring |
| `uvm/fswwdt_sequences.sv` | Directed and random sequences |
| `uvm/fswwdt_base_test.sv` / `fswwdt_tests.sv` | Tests |
| `uvm/tb_top.sv` | Clocks, DUT, `run_test` |
| `sva/fswwdt_sva.sv` | Core assertions |
