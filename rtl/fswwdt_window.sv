// ----------------------------------------------------------------------------
// Open-window threshold.
//   WIN_SEL 00 : 50%   of timeout
//   WIN_SEL 01 : 25%   of timeout
//   WIN_SEL 10 : 75%   of timeout
//   WIN_SEL 11 : 12.5% of timeout
// Integer truncation is used. The threshold is clamped so the closed region
// and the open region are each at least one count when timeout >= 2.
// ----------------------------------------------------------------------------
`default_nettype none

module fswwdt_window (
  input  logic [fswwdt_pkg::CNT_W-1:0] to_val,
  input  logic [1:0]                   win_sel,
  output logic [fswwdt_pkg::CNT_W-1:0] win_thr
);
  import fswwdt_pkg::*;

  logic [CNT_W-1:0] raw;

  always_comb begin
    case (win_sel)
      2'b00:   raw = to_val >> 1;
      2'b01:   raw = to_val >> 2;
      2'b10:   raw = (to_val >> 1) + (to_val >> 2);
      2'b11:   raw = to_val >> 3;
      default: raw = to_val >> 1;
    endcase

    if (raw == '0)
      raw = {{(CNT_W-1){1'b0}}, 1'b1};
    if (raw >= to_val)
      raw = to_val - {{(CNT_W-1){1'b0}}, 1'b1};

    win_thr = raw;
  end
endmodule

`default_nettype wire
