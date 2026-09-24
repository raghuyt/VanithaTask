class fswwdt_monitor extends uvm_monitor;
  `uvm_component_utils(fswwdt_monitor)

  virtual fswwdt_if vif;
  uvm_analysis_port #(fswwdt_seq_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual fswwdt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "APB monitor did not get the virtual interface")
  endfunction

  task run_phase(uvm_phase phase);
    fswwdt_seq_item item;
    forever begin
      @(posedge vif.pclk);
      if ((vif.preset_n === 1'b1) && vif.psel && vif.penable && vif.pready) begin
        item = fswwdt_seq_item::type_id::create("item");
        item.write  = vif.pwrite;
        item.addr   = vif.paddr;
        item.data   = vif.pwdata;
        item.rdata  = vif.prdata;
        item.slverr = vif.pslverr;
        item.ready  = vif.pready;
        ap.write(item);
      end
    end
  endtask
endclass
