// ----------------------------------------------------------------------------
// Status return path, wdt_clk -> pclk.
// Single-bit flags use a 2-flop synchronizer.
// err_cnt moves by +1 or -1, so it is Gray-coded before the 2-flop bank.
// The pclk register file samples a coherent value, two pclk late.
// ----------------------------------------------------------------------------
`default_nettype none

module fswwdt_status_sync (
  input  logic       wdt_clk,
  input  logic       wdt_rst_n,
  input  logic       pclk,
  input  logic       p_rst_n,
  input  logic       running,
  input  logic       win_open,
  input  logic       to_err,
  input  logic       early_err,
  input  logic       irq_pend,
  input  logic       rst_pend,
  input  logic       fail_ind,
  input  logic [7:0] err_cnt,
  output logic       running_s,
  output logic       win_open_s,
  output logic       to_err_s,
  output logic       early_err_s,
  output logic       irq_pend_s,
  output logic       rst_pend_s,
  output logic       fail_ind_s,
  output logic [7:0] err_cnt_s
);
  import fswwdt_pkg::*;

  logic [7:0] gray_q;
  logic [7:0] gray_s;

  always_ff @(posedge wdt_clk or negedge wdt_rst_n) begin
    if (!wdt_rst_n)
      gray_q <= 8'h00;
    else
      gray_q <= bin2gray(err_cnt);
  end

  fswwdt_sync2_vec #(.W(1)) u_running (.clk(pclk), .rst_n(p_rst_n), .d(running),   .q(running_s));
  fswwdt_sync2_vec #(.W(1)) u_win     (.clk(pclk), .rst_n(p_rst_n), .d(win_open),  .q(win_open_s));
  fswwdt_sync2_vec #(.W(1)) u_to      (.clk(pclk), .rst_n(p_rst_n), .d(to_err),    .q(to_err_s));
  fswwdt_sync2_vec #(.W(1)) u_early   (.clk(pclk), .rst_n(p_rst_n), .d(early_err), .q(early_err_s));
  fswwdt_sync2_vec #(.W(1)) u_irq     (.clk(pclk), .rst_n(p_rst_n), .d(irq_pend),  .q(irq_pend_s));
  fswwdt_sync2_vec #(.W(1)) u_rst     (.clk(pclk), .rst_n(p_rst_n), .d(rst_pend),  .q(rst_pend_s));
  fswwdt_sync2_vec #(.W(1)) u_fail    (.clk(pclk), .rst_n(p_rst_n), .d(fail_ind),  .q(fail_ind_s));
  fswwdt_sync2_vec #(.W(8)) u_gray    (.clk(pclk), .rst_n(p_rst_n), .d(gray_q),    .q(gray_s));

  assign err_cnt_s = gray2bin(gray_s);
endmodule

`default_nettype wire
