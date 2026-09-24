class fswwdt_wdt_monitor extends uvm_monitor;
  `uvm_component_utils(fswwdt_wdt_monitor)

  virtual fswwdt_if vif;
  uvm_analysis_port #(fswwdt_wdt_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual fswwdt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "WDT monitor did not get the virtual interface")
  endfunction

  task publish(fswwdt_wdt_item::ev_e kind);
    fswwdt_wdt_item item;
    item = fswwdt_wdt_item::type_id::create("item");
    item.kind = kind;
    ap.write(item);
  endtask

  task run_phase(uvm_phase phase);
    bit irq_q, rst_q, fail_q;
    irq_q  = 1'b0;
    rst_q  = 1'b0;
    fail_q = 1'b0;
    forever begin
      @(posedge vif.wdt_clk);
      if (vif.wdt_rst_n !== 1'b1) begin
        irq_q  = 1'b0;
        rst_q  = 1'b0;
        fail_q = 1'b0;
      end else begin
        if (vif.wdt_irq && !irq_q)
          publish(fswwdt_wdt_item::EV_IRQ);
        if (vif.wdt_reset_req && !rst_q)
          publish(fswwdt_wdt_item::EV_RESET);
        if (vif.wdt_fail_ind && !fail_q)
          publish(fswwdt_wdt_item::EV_FAIL);
        irq_q  = vif.wdt_irq;
        rst_q  = vif.wdt_reset_req;
        fail_q = vif.wdt_fail_ind;
      end
    end
  endtask
endclass
