// Passive agent: the watchdog outputs are observed, never driven.
class fswwdt_wdt_agent extends uvm_agent;
  `uvm_component_utils(fswwdt_wdt_agent)

  fswwdt_wdt_monitor mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    is_active = UVM_PASSIVE;
    mon = fswwdt_wdt_monitor::type_id::create("mon", this);
  endfunction
endclass
