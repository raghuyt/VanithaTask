// ----------------------------------------------------------------------------
// Free-running window counter. The core FSM decides step vs clear.
// Clear wins if both are ever asserted together.
// ----------------------------------------------------------------------------
`default_nettype none

module fswwdt_counter (
  input  logic                         clk,
  input  logic                         rst_n,
  input  logic                         clear,
  input  logic                         step,
  output logic [fswwdt_pkg::CNT_W-1:0] count
);
  import fswwdt_pkg::*;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      count <= '0;
    else if (clear)
      count <= '0;
    else if (step)
      count <= count + {{(CNT_W-1){1'b0}}, 1'b1};
  end
endmodule

`default_nettype wire
