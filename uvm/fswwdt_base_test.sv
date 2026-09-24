class fswwdt_base_test extends uvm_test;
  `uvm_component_utils(fswwdt_base_test)

  fswwdt_env env;
  virtual fswwdt_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = fswwdt_env::type_id::create("env", this);
    if (!uvm_config_db#(virtual fswwdt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "base test did not get the virtual interface")
    uvm_config_db#(virtual fswwdt_if)::set(this, "env.*", "vif", vif);
  endfunction

  task do_reset(int cycles = 5);
    vif.wdt_clk_en = 1'b1;
    vif.preset_n   = 1'b0;
    vif.wdt_rst_n  = 1'b0;
    repeat (cycles) @(posedge vif.pclk);
    vif.preset_n  = 1'b1;
    vif.wdt_rst_n = 1'b1;
    repeat (cycles) @(posedge vif.pclk);
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    do_reset();
    run_test_seq();
    phase.drop_objection(this);
  endtask

  virtual task run_test_seq();
    `uvm_info("TEST", "base test reset complete", UVM_LOW)
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();
    if ((svr.get_severity_count(UVM_ERROR) != 0) ||
        (svr.get_severity_count(UVM_FATAL) != 0))
      $display("TEST FAILED");
    else
      $display("TEST PASSED");
  endfunction
endclass
