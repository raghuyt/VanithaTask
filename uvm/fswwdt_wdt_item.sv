class fswwdt_wdt_item extends uvm_sequence_item;
  typedef enum bit [1:0] {EV_IRQ, EV_RESET, EV_FAIL} ev_e;
  ev_e kind;

  `uvm_object_utils(fswwdt_wdt_item)

  function new(string name = "fswwdt_wdt_item");
    super.new(name);
  endfunction
endclass
