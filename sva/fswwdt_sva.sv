// ----------------------------------------------------------------------------
// Functional assertions for the watchdog core.
// Instantiated from fswwdt_core when FSWWDT_ASSERT is defined.
// Sampled on wdt_clk. Disable while reset is asserted.
// ----------------------------------------------------------------------------
`default_nettype none

module fswwdt_sva (
  input logic                          clk,
  input logic                          rst_n,
  input logic                          en,
  input logic                          win_en,
  input fswwdt_pkg::wdt_st_e           state,
  input logic [fswwdt_pkg::CNT_W-1:0]  count,
  input logic [fswwdt_pkg::CNT_W-1:0]  win_thr,
  input logic                          step,
  input logic                          clear,
  input logic                          early_pulse,
  input logic                          to_pulse,
  input logic                          valid_srv,
  input logic                          do_irq,
  input logic                          do_reset,
  input logic                          to_err,
  input logic                          early_err,
  input logic                          irq,
  input logic                          reset_req,
  input logic [7:0]                    err_cnt
);
  import fswwdt_pkg::*;

  // Window checks use $stable so a same-cycle config update is not a false fail.
  a_step_clear_mutex: assert property (@(posedge clk) disable iff (!rst_n)
    !(step && clear))
    else $error("FSWWDT: step and clear asserted together");

  a_idle_count: assert property (@(posedge clk) disable iff (!rst_n)
    (state == ST_IDLE) |-> (count == '0))
    else $error("FSWWDT: count not zero in IDLE");

  a_leave_idle: assert property (@(posedge clk) disable iff (!rst_n)
    (en && (state == ST_IDLE)) |=> (state != ST_IDLE))
    else $error("FSWWDT: enable did not leave IDLE");

  a_closed_below_thr: assert property (@(posedge clk) disable iff (!rst_n)
    ((state == ST_CLOSED) && $stable(win_thr)) |-> (count < win_thr))
    else $error("FSWWDT: CLOSED with count at or past the open point");

  a_open_at_or_past_thr: assert property (@(posedge clk) disable iff (!rst_n)
    ((state == ST_OPEN) && win_en && $stable(win_en) && $stable(win_thr))
      |-> (count >= win_thr))
    else $error("FSWWDT: OPEN below the window threshold");

  a_early_not_with_valid: assert property (@(posedge clk) disable iff (!rst_n)
    !(early_pulse && valid_srv));

  a_early_not_with_timeout: assert property (@(posedge clk) disable iff (!rst_n)
    !(early_pulse && to_pulse));

  a_timeout_flag: assert property (@(posedge clk) disable iff (!rst_n)
    to_pulse |=> (to_err || !en))
    else $error("FSWWDT: timeout did not set TO_ERR");

  a_early_flag: assert property (@(posedge clk) disable iff (!rst_n)
    early_pulse |=> (early_err || !en))
    else $error("FSWWDT: early service did not set EARLY_ERR");

  a_irq_on_fault: assert property (@(posedge clk) disable iff (!rst_n)
    do_irq |=> (irq || !en))
    else $error("FSWWDT: fault with irq_en did not raise wdt_irq");

  a_reset_on_fatal: assert property (@(posedge clk) disable iff (!rst_n)
    do_reset |=> (reset_req || !en))
    else $error("FSWWDT: fatal fault did not raise wdt_reset_req");

  // Width is counted from the first cycle reset_req is observed high.
  a_reset_pulse_width: assert property (@(posedge clk) disable iff (!rst_n)
    ($rose(reset_req) && en) |->
      (reset_req && en)[*RST_PULSE_W] ##1 (!reset_req || !en))
    else $error("FSWWDT: reset pulse width is not %0d cycles", RST_PULSE_W);

  a_err_inc: assert property (@(posedge clk) disable iff (!rst_n)
    ((early_pulse || to_pulse) && (err_cnt != 8'hFF)) |=>
      ((err_cnt == ($past(err_cnt) + 8'd1)) || !en))
    else $error("FSWWDT: error counter did not increment");

  a_err_dec: assert property (@(posedge clk) disable iff (!rst_n)
    (valid_srv && (err_cnt != 8'h00)) |=>
      ((err_cnt == ($past(err_cnt) - 8'd1)) || !en))
    else $error("FSWWDT: good service did not decrement the error counter");

  a_valid_reloads: assert property (@(posedge clk) disable iff (!rst_n)
    valid_srv |=> (count == '0))
    else $error("FSWWDT: legal service did not reload the counter");

  c_arc_closed_to_open: cover property (@(posedge clk) disable iff (!rst_n)
    (state == ST_CLOSED) ##1 (state == ST_OPEN));
  c_arc_early: cover property (@(posedge clk) disable iff (!rst_n) early_pulse);
  c_arc_timeout: cover property (@(posedge clk) disable iff (!rst_n) to_pulse);
  c_arc_reset: cover property (@(posedge clk) disable iff (!rst_n) $rose(reset_req));
  c_arc_good_service: cover property (@(posedge clk) disable iff (!rst_n) valid_srv);
endmodule

`default_nettype wire
