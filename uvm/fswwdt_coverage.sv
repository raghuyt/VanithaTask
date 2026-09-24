class fswwdt_coverage extends uvm_component;
  `uvm_component_utils(fswwdt_coverage)

  uvm_analysis_imp_apb #(fswwdt_seq_item, fswwdt_coverage) apb_imp;
  uvm_analysis_imp_wdt #(fswwdt_wdt_item, fswwdt_coverage) wdt_imp;

  typedef enum bit [1:0] {FLT_EARLY, FLT_TIMEOUT} flt_e;

  bit [1:0]  last_win_sel;
  bit        last_win_en;
  bit [7:0]  addr;
  bit        write, slverr, en, win_en, cfg_sample, ctrl_sample;
  bit        saw_irq, saw_reset;
  bit [1:0]  win_sel;
  bit [15:0] to_val;
  flt_e      flt;

  covergroup cg_apb;
    option.per_instance = 1;
    cp_addr: coverpoint addr {
      bins ctrl    = {8'h00};
      bins cfg     = {8'h04};
      bins srv     = {8'h08};
      bins stat    = {8'h0C};
      bins errcnt  = {8'h10};
      bins unlock  = {8'h14};
      bins intclr  = {8'h18};
      bins id      = {8'h1C};
      bins illegal = default;
    }
    cp_write: coverpoint write { bins rd = {0}; bins wr = {1}; }
    cp_slverr: coverpoint slverr { bins ok = {0}; bins err = {1}; }
    cp_win_sel: coverpoint win_sel iff (cfg_sample) {
      bins s50  = {2'b00};
      bins s25  = {2'b01};
      bins s75  = {2'b10};
      bins s125 = {2'b11};
    }
    cp_to_range: coverpoint to_val iff (cfg_sample) {
      bins small  = {[16'd2:16'd31]};
      bins medium = {[16'd32:16'd255]};
      bins large  = {[16'd256:$]};
    }
    cp_en: coverpoint en iff (ctrl_sample) { bins off = {0}; bins on = {1}; }
    cp_win_en: coverpoint win_en iff (ctrl_sample) { bins off = {0}; bins on = {1}; }
    cx_addr_write: cross cp_addr, cp_write;
  endgroup

  covergroup cg_fault;
    option.per_instance = 1;
    cp_win_sel: coverpoint win_sel {
      bins s50  = {2'b00};
      bins s25  = {2'b01};
      bins s75  = {2'b10};
      bins s125 = {2'b11};
    }
    cp_flt: coverpoint flt {
      bins early   = {FLT_EARLY};
      bins timeout = {FLT_TIMEOUT};
    }
    cx_win_flt: cross cp_win_sel, cp_flt;
  endgroup

  covergroup cg_evt;
    option.per_instance = 1;
    cp_irq: coverpoint saw_irq { bins hit = {1}; }
    cp_reset: coverpoint saw_reset { bins hit = {1}; }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_apb   = new();
    cg_fault = new();
    cg_evt   = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb_imp = new("apb_imp", this);
    wdt_imp = new("wdt_imp", this);
  endfunction

  function void write_apb(fswwdt_seq_item t);
    addr        = t.addr;
    write       = t.write;
    slverr      = t.slverr;
    cfg_sample  = 1'b0;
    ctrl_sample = 1'b0;
    en          = 1'b0;
    win_en      = last_win_en;
    win_sel     = last_win_sel;
    to_val      = 16'd256;

    if (t.write && !t.slverr && (t.addr == fswwdt_pkg::ADDR_CFG)) begin
      cfg_sample   = 1'b1;
      last_win_sel = t.data[17:16];
      win_sel      = last_win_sel;
      to_val       = (t.data[15:0] < 16'd2) ? 16'd2 : t.data[15:0];
    end
    if (t.write && !t.slverr && (t.addr == fswwdt_pkg::ADDR_CTRL)) begin
      ctrl_sample = 1'b1;
      en          = t.data[0];
      last_win_en = t.data[1];
      win_en      = last_win_en;
    end
    cg_apb.sample();

    if (!t.write && !t.slverr && (t.addr == fswwdt_pkg::ADDR_STAT)) begin
      if (t.rdata[3])
        sample_flt(FLT_EARLY);
      if (t.rdata[2])
        sample_flt(FLT_TIMEOUT);
    end
  endfunction

  function void write_wdt(fswwdt_wdt_item t);
    if (t.kind == fswwdt_wdt_item::EV_IRQ) begin
      saw_irq = 1'b1;
      cg_evt.sample();
    end
    if (t.kind == fswwdt_wdt_item::EV_RESET) begin
      saw_reset = 1'b1;
      cg_evt.sample();
    end
  endfunction

  function void sample_flt(flt_e kind);
    flt     = kind;
    win_sel = last_win_sel;
    cg_fault.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    real apb_c, flt_c, evt_c;
    super.report_phase(phase);
    apb_c = cg_apb.get_inst_coverage();
    flt_c = cg_fault.get_inst_coverage();
    evt_c = cg_evt.get_inst_coverage();
    `uvm_info("COV", $sformatf(
      "APB %0.1f%%  window/fault %0.1f%%  irq/reset %0.1f%%",
      apb_c, flt_c, evt_c), UVM_LOW)
  endfunction
endclass
