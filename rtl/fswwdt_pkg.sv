// ----------------------------------------------------------------------------
// Package : fswwdt_pkg
// Shared RTL constants for the Fail-Safe Window Watchdog Timer.
// Register layout, service key, and the config word pushed into wdt_clk.
// ----------------------------------------------------------------------------
`ifndef FSWWDT_PKG_SV
`define FSWWDT_PKG_SV

package fswwdt_pkg;

  localparam int unsigned ADDR_W       = 8;
  localparam int unsigned DATA_W       = 32;
  localparam int unsigned CNT_W        = 16;
  localparam int unsigned RST_PULSE_W  = 8;

  // Service is a data-matched write so a runaway store is unlikely to pet the dog.
  localparam logic [31:0] SRV_KEY     = 32'h5A5A_A5A5;
  localparam logic [31:0] UNLOCK_KEY1 = 32'hC3C3_3C3C;
  localparam logic [31:0] UNLOCK_KEY2 = 32'h3C3C_C3C3;
  localparam logic [31:0] ID_VALUE    = 32'h4653_5754; // ASCII "FSWT"

  localparam logic [7:0] ADDR_CTRL   = 8'h00;
  localparam logic [7:0] ADDR_CFG    = 8'h04;
  localparam logic [7:0] ADDR_SRV    = 8'h08;
  localparam logic [7:0] ADDR_STAT   = 8'h0C;
  localparam logic [7:0] ADDR_ERRCNT = 8'h10;
  localparam logic [7:0] ADDR_UNLOCK = 8'h14;
  localparam logic [7:0] ADDR_INTCLR = 8'h18;
  localparam logic [7:0] ADDR_ID     = 8'h1C;

  // Minimum programmable timeout is 2 wdt_clk ticks so the window math
  // always has a closed sample and an open sample.
  localparam logic [CNT_W-1:0] TO_VAL_MIN   = 16'd2;
  localparam logic [CNT_W-1:0] TO_VAL_RESET = 16'd256;
  localparam logic [7:0]       THRESH_RESET = 8'd3;

  // Config snapshot transferred pclk -> wdt_clk. First field is the MSB.
  // [31:30] rsvd
  // [29:22] err_thresh
  // [21:6]  to_val
  // [5:4]   win_sel
  // [3]     rst_en  [2] irq_en  [1] win_en  [0] en
  // Reset image of the defaults below is 32'h00C0_400C.
  typedef struct packed {
    logic [1:0]        rsvd;
    logic [7:0]        err_thresh;
    logic [CNT_W-1:0]  to_val;
    logic [1:0]        win_sel;
    logic              rst_en;
    logic              irq_en;
    logic              win_en;
    logic              en;
  } cfg_snap_t;

  typedef enum logic [1:0] {
    ST_IDLE   = 2'd0,
    ST_CLOSED = 2'd1,
    ST_OPEN   = 2'd2,
    ST_RESET  = 2'd3
  } wdt_st_e;

  function automatic logic addr_mapped(input logic [ADDR_W-1:0] addr);
    if (addr[1:0] != 2'b00)
      return 1'b0;
    case (addr)
      ADDR_CTRL, ADDR_CFG, ADDR_SRV, ADDR_STAT,
      ADDR_ERRCNT, ADDR_UNLOCK, ADDR_INTCLR, ADDR_ID: return 1'b1;
      default: return 1'b0;
    endcase
  endfunction

  function automatic logic addr_protected(input logic [ADDR_W-1:0] addr);
    return (addr == ADDR_CTRL) || (addr == ADDR_CFG) || (addr == ADDR_ERRCNT);
  endfunction

  // Next fault reaches the threshold. A programmed threshold of 0 is treated
  // as 1 so the counter cannot be configured to "never fatal".
  function automatic logic is_fatal(
    input logic [7:0] cnt,
    input logic [7:0] thresh
  );
    logic [7:0] th;
    logic [8:0] nxt;
    begin
      th  = (thresh == 8'd0) ? 8'd1 : thresh;
      nxt = {1'b0, cnt} + 9'd1;
      return (nxt >= {1'b0, th});
    end
  endfunction

  function automatic logic [7:0] bin2gray(input logic [7:0] b);
    return b ^ (b >> 1);
  endfunction

  function automatic logic [7:0] gray2bin(input logic [7:0] g);
    logic [7:0] b;
    begin
      b[7] = g[7];
      b[6] = b[7] ^ g[6];
      b[5] = b[6] ^ g[5];
      b[4] = b[5] ^ g[4];
      b[3] = b[4] ^ g[3];
      b[2] = b[3] ^ g[2];
      b[1] = b[2] ^ g[1];
      b[0] = b[1] ^ g[0];
      return b;
    end
  endfunction

endpackage

`endif
