package fswwdt_uvm_pkg;
  import uvm_pkg::*;
  import fswwdt_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_apb)
  `uvm_analysis_imp_decl(_wdt)

  `include "fswwdt_seq_item.sv"
  `include "fswwdt_wdt_item.sv"
  `include "fswwdt_reg_model.sv"
  `include "fswwdt_sequencer.sv"
  `include "fswwdt_driver.sv"
  `include "fswwdt_monitor.sv"
  `include "fswwdt_wdt_monitor.sv"
  `include "fswwdt_agent.sv"
  `include "fswwdt_wdt_agent.sv"
  `include "fswwdt_scoreboard.sv"
  `include "fswwdt_coverage.sv"
  `include "fswwdt_env.sv"
  `include "fswwdt_sequences.sv"
  `include "fswwdt_base_test.sv"
  `include "fswwdt_tests.sv"
endpackage
