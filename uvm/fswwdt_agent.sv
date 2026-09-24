class fswwdt_agent extends uvm_agent;
  `uvm_component_utils(fswwdt_agent)

  fswwdt_driver    drv;
  fswwdt_monitor   mon;
  fswwdt_sequencer sqr;
  virtual fswwdt_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fswwdt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "APB agent did not get the virtual interface")
    uvm_config_db#(virtual fswwdt_if)::set(this, "*", "vif", vif);
    mon = fswwdt_monitor::type_id::create("mon", this);
    if (is_active == UVM_ACTIVE) begin
      drv = fswwdt_driver::type_id::create("drv", this);
      sqr = fswwdt_sequencer::type_id::create("sqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
