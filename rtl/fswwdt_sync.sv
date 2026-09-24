// ----------------------------------------------------------------------------
// Clock-domain primitives.
// Reset: async assert, sync deassert.
// Data:  2-flop synchronizer. Use only for single bits or a Gray vector.
// ----------------------------------------------------------------------------
`default_nettype none

module fswwdt_reset_sync (
  input  logic clk,
  input  logic rst_n_async,
  output logic rst_n_sync
);
  (* ASYNC_REG = "TRUE" *) logic ff1;
  (* ASYNC_REG = "TRUE" *) logic ff2;

  always_ff @(posedge clk or negedge rst_n_async) begin
    if (!rst_n_async) begin
      ff1 <= 1'b0;
      ff2 <= 1'b0;
    end else begin
      ff1 <= 1'b1;
      ff2 <= ff1;
    end
  end

  assign rst_n_sync = ff2;
endmodule

module fswwdt_sync2_vec #(
  parameter int unsigned W = 1
) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic [W-1:0]     d,
  output logic [W-1:0]     q
);
  (* ASYNC_REG = "TRUE" *) logic [W-1:0] ff1;
  (* ASYNC_REG = "TRUE" *) logic [W-1:0] ff2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ff1 <= '0;
      ff2 <= '0;
    end else begin
      ff1 <= d;
      ff2 <= ff1;
    end
  end

  assign q = ff2;
endmodule

`default_nettype wire
