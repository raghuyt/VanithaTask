class fswwdt_reg_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_reg_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_reg_seq seq = fswwdt_reg_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_basic_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_basic_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_basic_seq seq = fswwdt_basic_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_window_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_window_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_window_seq seq = fswwdt_window_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_timeout_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_timeout_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_timeout_seq seq = fswwdt_timeout_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_early_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_early_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_early_seq seq = fswwdt_early_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_late_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_late_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_late_seq seq = fswwdt_late_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_irq_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_irq_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_irq_seq seq = fswwdt_irq_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_reset_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_reset_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_reset_seq seq = fswwdt_reset_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_err_inject_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_err_inject_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_err_seq seq = fswwdt_err_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_por_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_por_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_por_seq seq = fswwdt_por_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_warm_reset_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_warm_reset_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_warm_seq seq = fswwdt_warm_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_async_reset_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_async_reset_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_async_rst_seq seq = fswwdt_async_rst_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_sync_reset_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_sync_reset_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_sync_rst_seq seq = fswwdt_sync_rst_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_clk_stop_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_clk_stop_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_clk_stop_seq seq = fswwdt_clk_stop_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_freq_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_freq_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_freq_seq seq = fswwdt_freq_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_reset_during_run_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_reset_during_run_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_rst_during_run_seq seq = fswwdt_rst_during_run_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_reset_during_to_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_reset_during_to_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_rst_during_to_seq seq = fswwdt_rst_during_to_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_cov_fill_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_cov_fill_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_cov_seq seq = fswwdt_cov_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass

class fswwdt_rand_test extends fswwdt_base_test;
  `uvm_component_utils(fswwdt_rand_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_test_seq();
    fswwdt_rand_seq seq = fswwdt_rand_seq::type_id::create("seq");
    seq.start(env.apb.sqr);
  endtask
endclass
