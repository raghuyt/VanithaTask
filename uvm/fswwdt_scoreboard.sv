class fswwdt_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(fswwdt_scoreboard)

  uvm_analysis_imp_apb #(fswwdt_seq_item, fswwdt_scoreboard) apb_imp;
  uvm_analysis_imp_wdt #(fswwdt_wdt_item, fswwdt_scoreboard) wdt_imp;

  fswwdt_reg_model model;
  virtual fswwdt_if vif;
  int unsigned n_apb, n_irq, n_reset, n_fail, n_err;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb_imp = new("apb_imp", this);
    wdt_imp = new("wdt_imp", this);
    model   = fswwdt_reg_model::type_id::create("model");
    if (!uvm_config_db#(virtual fswwdt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "scoreboard did not get the virtual interface")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(negedge vif.preset_n);
      model.reset();
    end
  endtask

  function void write_wdt(fswwdt_wdt_item t);
    case (t.kind)
      fswwdt_wdt_item::EV_IRQ:    n_irq++;
      fswwdt_wdt_item::EV_RESET:  n_reset++;
      fswwdt_wdt_item::EV_FAIL:   n_fail++;
      default: begin
      end
    endcase
  endfunction

  function void write_apb(fswwdt_seq_item t);
    bit exp_slverr;
    n_apb++;
    if (t.ready !== 1'b1) begin
      `uvm_error("APB", "PREADY was not high in the access phase")
      n_err++;
    end

    if (t.write) begin
      exp_slverr = model.predict_write(t.addr, t.data);
      if (t.slverr !== exp_slverr) begin
        `uvm_error("REG", $sformatf(
          "write addr 0x%02h data 0x%08h PSLVERR=%0b expected %0b",
          t.addr, t.data, t.slverr, exp_slverr))
        n_err++;
      end
    end else begin
      check_read(t.addr, t.rdata, t.slverr);
    end
  endfunction

  function void check_read(bit [7:0] addr, bit [31:0] rdata, bit slverr);
    bit [31:0] exp;
    bit        exp_slverr;

    exp_slverr = !fswwdt_pkg::addr_mapped(addr);
    if (slverr !== exp_slverr) begin
      `uvm_error("REG", $sformatf(
        "read addr 0x%02h PSLVERR=%0b expected %0b", addr, slverr, exp_slverr))
      n_err++;
      return;
    end
    if (exp_slverr) begin
      if (rdata !== '0) begin
        `uvm_error("REG", $sformatf("illegal read returned 0x%08h", rdata))
        n_err++;
      end
      return;
    end

    case (addr)
      fswwdt_pkg::ADDR_CTRL: begin
        exp = {27'd0, model.lock, model.rst_en, model.irq_en, model.win_en, model.en};
        compare("CTRL", rdata, exp);
      end
      fswwdt_pkg::ADDR_CFG: begin
        exp = {14'd0, model.win_sel, model.to_val};
        compare("CFG", rdata, exp);
      end
      fswwdt_pkg::ADDR_ERRCNT: begin
        if (rdata[31:16] !== 16'h0 || rdata[15:8] !== model.err_thresh) begin
          `uvm_error("REG", $sformatf(
            "ERRCNT 0x%08h thresh expected 0x%02h", rdata, model.err_thresh))
          n_err++;
        end
      end
      fswwdt_pkg::ADDR_STAT: begin
        if (rdata[31:11] !== 21'h0) begin
          `uvm_error("REG", $sformatf("STAT reserved bits set: 0x%08h", rdata))
          n_err++;
        end
        if (rdata[9] !== (model.ul == 2'd2) ||
            rdata[7] !== model.lock ||
            rdata[6] !== model.bad_srv) begin
          `uvm_error("REG", $sformatf(
            "STAT bus-domain bits 0x%08h lock=%0b bad=%0b ul=%0d",
            rdata, model.lock, model.bad_srv, model.ul))
          n_err++;
        end
      end
      fswwdt_pkg::ADDR_ID: compare("ID", rdata, fswwdt_pkg::ID_VALUE);
      fswwdt_pkg::ADDR_SRV,
      fswwdt_pkg::ADDR_UNLOCK,
      fswwdt_pkg::ADDR_INTCLR: compare("WO", rdata, 32'h0);
      default: begin
      end
    endcase
  endfunction

  function void compare(string name, bit [31:0] got, bit [31:0] exp);
    if (got !== exp) begin
      `uvm_error("REG", $sformatf("%s read 0x%08h expected 0x%08h", name, got, exp))
      n_err++;
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf(
      "apb=%0d irq_rise=%0d reset_rise=%0d fail_rise=%0d mismatches=%0d",
      n_apb, n_irq, n_reset, n_fail, n_err), UVM_LOW)
  endfunction
endclass
