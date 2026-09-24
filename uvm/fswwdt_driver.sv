class fswwdt_driver extends uvm_driver #(fswwdt_seq_item);
  `uvm_component_utils(fswwdt_driver)

  virtual fswwdt_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fswwdt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "APB driver did not get the virtual interface")
  endfunction

  task run_phase(uvm_phase phase);
    fswwdt_seq_item tr;
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite  <= 1'b0;
    vif.paddr   <= '0;
    vif.pwdata  <= '0;

    forever begin
      seq_item_port.get_next_item(tr);
      if (vif.preset_n !== 1'b1) begin
        vif.psel    <= 1'b0;
        vif.penable <= 1'b0;
        seq_item_port.item_done();
        @(posedge vif.pclk);
        continue;
      end

      // Setup
      @(posedge vif.pclk);
      vif.paddr   <= tr.addr;
      vif.pwdata  <= tr.data;
      vif.pwrite  <= tr.write;
      vif.psel    <= 1'b1;
      vif.penable <= 1'b0;

      // Access
      @(posedge vif.pclk);
      vif.penable <= 1'b1;

      // Sample at the end of the access phase, then return to idle.
      @(posedge vif.pclk);
      tr.rdata  = vif.prdata;
      tr.slverr = vif.pslverr;
      tr.ready  = vif.pready;
      vif.psel    <= 1'b0;
      vif.penable <= 1'b0;
      seq_item_port.item_done();
    end
  endtask
endclass
