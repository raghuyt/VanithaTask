// ----------------------------------------------------------------------------
// FSWWDT top.
// pclk    : APB register file
// wdt_clk : counter, window, interrupt and reset request
//
// preset_n resets only the bus domain. An already-running counter keeps
// running, so a hung CPU whose bus reset asserts cannot silence the dog.
// wdt_rst_n resets the counter domain. When that reset is released, the
// register file is pushed again so CTRL and the core match.
//
// Integration: wdt_clk must be an always-on clock that does not stop when
// the CPU clock stops. wdt_reset_req is synchronous to wdt_clk; the SoC
// reset controller stretches it and should also assert wdt_rst_n.
// ----------------------------------------------------------------------------
`default_nettype none

module fswwdt_top (
  input  logic                          pclk,
  input  logic                          preset_n,
  input  logic                          psel,
  input  logic                          penable,
  input  logic                          pwrite,
  input  logic [fswwdt_pkg::ADDR_W-1:0] paddr,
  input  logic [fswwdt_pkg::DATA_W-1:0] pwdata,
  output logic [fswwdt_pkg::DATA_W-1:0] prdata,
  output logic                          pready,
  output logic                          pslverr,

  input  logic                          wdt_clk,
  input  logic                          wdt_rst_n,

  output logic                          wdt_irq,
  output logic                          wdt_reset_req,
  output logic                          wdt_fail_ind
);
  import fswwdt_pkg::*;

  logic p_rst_n;
  logic w_rst_n;
  logic wdt_rst_lvl;

  logic                          cfg_push;
  logic [DATA_W-1:0]             cfg_bus;
  logic                          cfg_valid;
  logic [DATA_W-1:0]             cfg_wdt;
  logic                          srv_evt, srv_pulse, srv_lost;
  logic                          irq_clr_evt, irq_clr_pulse;
  logic                          rst_clr_evt, rst_clr_pulse;

  logic        running, win_open, to_err, early_err;
  logic        irq_w, reset_w, fail_w, irq_pend, rst_pend;
  logic [7:0]  err_cnt;
  logic        running_s, win_open_s, to_err_s, early_err_s;
  logic        irq_pend_s, rst_pend_s, fail_s;
  logic [7:0]  err_cnt_s;

  fswwdt_reset_sync u_prst (
    .clk         (pclk),
    .rst_n_async (preset_n),
    .rst_n_sync  (p_rst_n)
  );

  fswwdt_reset_sync u_wrst (
    .clk         (wdt_clk),
    .rst_n_async (wdt_rst_n),
    .rst_n_sync  (w_rst_n)
  );

  // Level only. The register file decides which rising edge is a real
  // watchdog-domain reset release.
  fswwdt_sync2_vec #(.W(1)) u_wdt_rst_lvl (
    .clk   (pclk),
    .rst_n (p_rst_n),
    .d     (wdt_rst_n),
    .q     (wdt_rst_lvl)
  );

  fswwdt_regs u_regs (
    .pclk        (pclk),
    .rst_n       (p_rst_n),
    .psel        (psel),
    .penable     (penable),
    .pwrite      (pwrite),
    .paddr       (paddr),
    .pwdata      (pwdata),
    .prdata      (prdata),
    .pready      (pready),
    .pslverr     (pslverr),
    .wdt_rst_lvl (wdt_rst_lvl),
    .cfg_push    (cfg_push),
    .cfg_bus     (cfg_bus),
    .srv_evt     (srv_evt),
    .irq_clr_evt (irq_clr_evt),
    .rst_clr_evt (rst_clr_evt),
    .running     (running_s),
    .win_open    (win_open_s),
    .to_err      (to_err_s),
    .early_err   (early_err_s),
    .irq_pend    (irq_pend_s),
    .rst_pend    (rst_pend_s),
    .fail_ind    (fail_s),
    .err_cnt     (err_cnt_s),
    .srv_lost    (srv_lost)
  );

  fswwdt_cfg_cdc #(.W(DATA_W)) u_cfg_cdc (
    .src_clk   (pclk),
    .src_rst_n (p_rst_n),
    .src_push  (cfg_push),
    .src_data  (cfg_bus),
    .dst_clk   (wdt_clk),
    .dst_rst_n (w_rst_n),
    .dst_valid (cfg_valid),
    .dst_data  (cfg_wdt)
  );

  fswwdt_pulse_cdc u_srv_cdc (
    .src_clk   (pclk),
    .src_rst_n (p_rst_n),
    .src_pulse (srv_evt),
    .dst_clk   (wdt_clk),
    .dst_rst_n (w_rst_n),
    .dst_pulse (srv_pulse),
    .overflow  (srv_lost)
  );

  fswwdt_pulse_cdc u_irqclr_cdc (
    .src_clk   (pclk),
    .src_rst_n (p_rst_n),
    .src_pulse (irq_clr_evt),
    .dst_clk   (wdt_clk),
    .dst_rst_n (w_rst_n),
    .dst_pulse (irq_clr_pulse),
    .overflow  ()
  );

  fswwdt_pulse_cdc u_rstclr_cdc (
    .src_clk   (pclk),
    .src_rst_n (p_rst_n),
    .src_pulse (rst_clr_evt),
    .dst_clk   (wdt_clk),
    .dst_rst_n (w_rst_n),
    .dst_pulse (rst_clr_pulse),
    .overflow  ()
  );

  fswwdt_core u_core (
    .clk           (wdt_clk),
    .rst_n         (w_rst_n),
    .cfg_valid     (cfg_valid),
    .cfg_bus       (cfg_wdt),
    .srv_pulse     (srv_pulse),
    .clr_irq_pulse (irq_clr_pulse),
    .clr_rst_pulse (rst_clr_pulse),
    .running       (running),
    .win_open      (win_open),
    .to_err        (to_err),
    .early_err     (early_err),
    .irq           (irq_w),
    .reset_req     (reset_w),
    .fail_ind      (fail_w),
    .irq_pend      (irq_pend),
    .rst_pend      (rst_pend),
    .err_cnt       (err_cnt)
  );

  fswwdt_status_sync u_stat (
    .wdt_clk     (wdt_clk),
    .wdt_rst_n   (w_rst_n),
    .pclk        (pclk),
    .p_rst_n     (p_rst_n),
    .running     (running),
    .win_open    (win_open),
    .to_err      (to_err),
    .early_err   (early_err),
    .irq_pend    (irq_pend),
    .rst_pend    (rst_pend),
    .fail_ind    (fail_w),
    .err_cnt     (err_cnt),
    .running_s   (running_s),
    .win_open_s  (win_open_s),
    .to_err_s    (to_err_s),
    .early_err_s (early_err_s),
    .irq_pend_s  (irq_pend_s),
    .rst_pend_s  (rst_pend_s),
    .fail_ind_s  (fail_s),
    .err_cnt_s   (err_cnt_s)
  );

  assign wdt_irq       = irq_w;
  assign wdt_reset_req = reset_w;
  assign wdt_fail_ind  = fail_w;
endmodule

`default_nettype wire
