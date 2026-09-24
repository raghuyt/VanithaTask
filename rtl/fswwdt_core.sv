// ----------------------------------------------------------------------------
// Window-watchdog controller (wdt_clk domain).
//
// States
//   IDLE    enable is low, count held at 0
//   CLOSED  window mode, count < open threshold; a service here is an early fault
//   OPEN    service is legal; missing the end of the window is a late fault
//   RESET   fail-safe reset pulse is active; count is held at 0
//
// A fault below the error threshold raises IRQ (if enabled) and restarts the
// count so software gets another window. A fault that reaches the threshold
// also pulses wdt_reset_req when reset generation is enabled.
// ----------------------------------------------------------------------------
`default_nettype none

module fswwdt_core (
  input  logic                          clk,
  input  logic                          rst_n,
  input  logic                          cfg_valid,
  input  logic [fswwdt_pkg::DATA_W-1:0] cfg_bus,
  input  logic                          srv_pulse,
  input  logic                          clr_irq_pulse,
  input  logic                          clr_rst_pulse,
  output logic                          running,
  output logic                          win_open,
  output logic                          to_err,
  output logic                          early_err,
  output logic                          irq,
  output logic                          reset_req,
  output logic                          fail_ind,
  output logic                          irq_pend,
  output logic                          rst_pend,
  output logic [7:0]                    err_cnt
);
  import fswwdt_pkg::*;

  logic [DATA_W-1:0] cfg_q;
  cfg_snap_t         cfg;
  logic [CNT_W-1:0]  to_val_c;
  logic [CNT_W-1:0]  win_thr;
  logic [CNT_W-1:0]  count;
  logic [CNT_W:0]    count_next;

  wdt_st_e state, next;
  logic    step, clear;
  logic    early_pulse, to_pulse, valid_srv;
  logic    fault_pulse, do_irq, do_reset;

  assign cfg      = cfg_snap_t'(cfg_q);
  assign to_val_c = (cfg.to_val < TO_VAL_MIN) ? TO_VAL_MIN : cfg.to_val;
  assign count_next = {1'b0, count} + {{CNT_W{1'b0}}, 1'b1};

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      cfg_q <= 32'h00C0_400C;
    else if (cfg_valid)
      cfg_q <= cfg_bus;
  end

`ifdef FSWWDT_ASSERT
  initial begin
    cfg_snap_t img;
    img.rsvd       = 2'b00;
    img.err_thresh = THRESH_RESET;
    img.to_val     = TO_VAL_RESET;
    img.win_sel    = 2'b00;
    img.rst_en     = 1'b1;
    img.irq_en     = 1'b1;
    img.win_en     = 1'b0;
    img.en         = 1'b0;
    if (img != 32'h00C0_400C)
      $error("FSWWDT cfg reset image mismatch: %h", img);
  end
`endif

  fswwdt_window u_window (
    .to_val  (to_val_c),
    .win_sel (cfg.win_sel),
    .win_thr (win_thr)
  );

  fswwdt_counter u_counter (
    .clk   (clk),
    .rst_n (rst_n),
    .clear (clear),
    .step  (step),
    .count (count)
  );

  always_comb begin
    next        = state;
    step        = 1'b0;
    clear       = 1'b0;
    early_pulse = 1'b0;
    to_pulse    = 1'b0;
    valid_srv   = 1'b0;

    case (state)
      ST_IDLE: begin
        clear = 1'b1;
        if (cfg.en)
          next = cfg.win_en ? ST_CLOSED : ST_OPEN;
      end

      ST_CLOSED: begin
        if (!cfg.en) begin
          clear = 1'b1;
          next  = ST_IDLE;
        end else if (!cfg.win_en) begin
          if (srv_pulse) begin
            valid_srv = 1'b1;
            clear     = 1'b1;
          end
          next = ST_OPEN;
        end else if (srv_pulse) begin
          early_pulse = 1'b1;
          clear       = 1'b1;
          next        = (is_fatal(err_cnt, cfg.err_thresh) && cfg.rst_en)
                        ? ST_RESET : ST_CLOSED;
        end else if (count_next >= {1'b0, win_thr}) begin
          step = 1'b1;
          next = ST_OPEN;
        end else begin
          step = 1'b1;
        end
      end

      ST_OPEN: begin
        if (!cfg.en) begin
          clear = 1'b1;
          next  = ST_IDLE;
        end else if (srv_pulse) begin
          valid_srv = 1'b1;
          clear     = 1'b1;
          next      = cfg.win_en ? ST_CLOSED : ST_OPEN;
        end else if (count_next >= {1'b0, to_val_c}) begin
          to_pulse = 1'b1;
          clear    = 1'b1;
          next     = (is_fatal(err_cnt, cfg.err_thresh) && cfg.rst_en)
                     ? ST_RESET : (cfg.win_en ? ST_CLOSED : ST_OPEN);
        end else begin
          step = 1'b1;
        end
      end

      ST_RESET: begin
        clear = 1'b1;
        if (!cfg.en)
          next = ST_IDLE;
        else if (!reset_req)
          next = cfg.win_en ? ST_CLOSED : ST_OPEN;
      end

      default: begin
        clear = 1'b1;
        next  = ST_IDLE;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= ST_IDLE;
    else
      state <= next;
  end

  assign fault_pulse = early_pulse || to_pulse;
  assign do_irq      = fault_pulse && cfg.irq_en;
  assign do_reset    = fault_pulse && cfg.rst_en && is_fatal(err_cnt, cfg.err_thresh);
  assign running     = (state != ST_IDLE);
  assign win_open    = (state == ST_OPEN);

  fswwdt_error u_error (
    .clk           (clk),
    .rst_n         (rst_n),
    .enable        (cfg.en),
    .fault         (fault_pulse),
    .valid_service (valid_srv),
    .err_cnt       (err_cnt)
  );

  fswwdt_irq #(.PULSE_W(RST_PULSE_W)) u_irq (
    .clk       (clk),
    .rst_n     (rst_n),
    .enable    (cfg.en),
    .set_irq   (do_irq),
    .set_reset (do_reset),
    .clr_irq   (clr_irq_pulse),
    .clr_rst   (clr_rst_pulse),
    .irq       (irq),
    .reset_req (reset_req),
    .fail_ind  (fail_ind),
    .irq_pend  (irq_pend),
    .rst_pend  (rst_pend)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || !cfg.en) begin
      to_err    <= 1'b0;
      early_err <= 1'b0;
    end else begin
      if (to_pulse)
        to_err <= 1'b1;
      else if (clr_irq_pulse)
        to_err <= 1'b0;

      if (early_pulse)
        early_err <= 1'b1;
      else if (clr_irq_pulse)
        early_err <= 1'b0;
    end
  end

`ifdef FSWWDT_ASSERT
  fswwdt_sva u_sva (
    .clk         (clk),
    .rst_n       (rst_n),
    .en          (cfg.en),
    .win_en      (cfg.win_en),
    .state       (state),
    .count       (count),
    .win_thr     (win_thr),
    .step        (step),
    .clear       (clear),
    .early_pulse (early_pulse),
    .to_pulse    (to_pulse),
    .valid_srv   (valid_srv),
    .do_irq      (do_irq),
    .do_reset    (do_reset),
    .to_err      (to_err),
    .early_err   (early_err),
    .irq         (irq),
    .reset_req   (reset_req),
    .err_cnt     (err_cnt)
  );
`endif
endmodule

`default_nettype wire
