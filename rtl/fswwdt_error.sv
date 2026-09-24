// ----------------------------------------------------------------------------
// Error counter.
//   fault          : +1 (saturates at 255)
//   valid service  : -1 (floors at 0)
//   disabled       : cleared
// A good pet forgives one previous fault. This is the usual automotive
// "error counter" recovery, not an instant clear.
// ----------------------------------------------------------------------------
`default_nettype none

module fswwdt_error (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       enable,
  input  logic       fault,
  input  logic       valid_service,
  output logic [7:0] err_cnt
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || !enable)
      err_cnt <= 8'h00;
    else if (fault)
      err_cnt <= (err_cnt == 8'hFF) ? 8'hFF : (err_cnt + 8'd1);
    else if (valid_service && (err_cnt != 8'h00))
      err_cnt <= err_cnt - 8'd1;
  end
endmodule

`default_nettype wire
