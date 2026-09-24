class fswwdt_sequencer extends uvm_sequencer #(fswwdt_seq_item);
  `uvm_component_utils(fswwdt_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
