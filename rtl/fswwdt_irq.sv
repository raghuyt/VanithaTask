// ----------------------------------------------------------------------------
// Interrupt level and fail-safe reset pulse.
// wdt_irq       sticky level, set on any fault while irq_en was already folded
//               into set_irq by the core
// wdt_reset_req pulse of PULSE_W wdt_clk cycles
// fail_ind      sticky until INTCLR[1] or disable / watchdog reset
// ----------------------------------------------------------------------------
`default_nettype none

module fswwdt_irq #(
  parameter int unsigned PULSE_W = 8
) (
  input  logic clk,
  input  logic rst_n,
  input  logic enable,
  input  logic set_irq,
  input  logic set_reset,
  input  logic clr_irq,
  input  logic clr_rst,
  output logic irq,
  output logic reset_req,
  output logic fail_ind,
  output logic irq_pend,
  output logic rst_pend
);
  logic [3:0] pulse_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || !enable) begin
      irq       <= 1'b0;
      reset_req <= 1'b0;
      fail_ind  <= 1'b0;
      pulse_cnt <= 4'h0;
    end else begin
      if (set_irq)
        irq <= 1'b1;
      else if (clr_irq)
        irq <= 1'b0;

      if (set_reset) begin
        reset_req <= 1'b1;
        fail_ind  <= 1'b1;
        pulse_cnt <= 4'(PULSE_W);
      end else if (pulse_cnt != 4'h0) begin
        pulse_cnt <= pulse_cnt - 4'd1;
        if (pulse_cnt == 4'd1)
          reset_req <= 1'b0;
      end

      if (clr_rst && !set_reset)
        fail_ind <= 1'b0;
    end
  end

  assign irq_pend = irq;
  assign rst_pend = fail_ind;
endmodule

`default_nettype wire
