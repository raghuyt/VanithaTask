`timescale 1ns/1ps

module tb_top;
  import uvm_pkg::*;
  import fswwdt_uvm_pkg::*;
  `include "uvm_macros.svh"

  logic pclk;
  logic wdt_clk_raw;
  logic wdt_clk_gated;
  logic wdt_en_q = 1'b1;
  int   wdt_period_ns = 100;

  wire wdt_clk = wdt_clk_gated;

  fswwdt_if vif(.pclk(pclk), .wdt_clk(wdt_clk));

  // Glitch-free gate: enable is sampled on the falling edge of the raw clock.
  always @(negedge wdt_clk_raw)
    wdt_en_q <= vif.wdt_clk_en;

  assign wdt_clk_gated = wdt_clk_raw & wdt_en_q;

  initial begin
    pclk = 1'b0;
    forever #5ns pclk = ~pclk;
  end

  initial begin
    if (!$value$plusargs("WDT_CLK_NS=%d", wdt_period_ns))
      wdt_period_ns = 100;
    if (wdt_period_ns < 2)
      wdt_period_ns = 2;
    wdt_clk_raw = 1'b0;
    forever #(wdt_period_ns / 2) wdt_clk_raw = ~wdt_clk_raw;
  end

  fswwdt_top dut (
    .pclk          (pclk),
    .preset_n      (vif.preset_n),
    .psel          (vif.psel),
    .penable       (vif.penable),
    .pwrite        (vif.pwrite),
    .paddr         (vif.paddr),
    .pwdata        (vif.pwdata),
    .prdata        (vif.prdata),
    .pready        (vif.pready),
    .pslverr       (vif.pslverr),
    .wdt_clk       (wdt_clk),
    .wdt_rst_n     (vif.wdt_rst_n),
    .wdt_irq       (vif.wdt_irq),
    .wdt_reset_req (vif.wdt_reset_req),
    .wdt_fail_ind  (vif.wdt_fail_ind)
  );

  initial begin
    if ($test$plusargs("DUMP")) begin
      $dumpfile("fswwdt.vcd");
      $dumpvars(0, tb_top);
    end
  end

  initial begin
    uvm_config_db#(virtual fswwdt_if)::set(null, "*", "vif", vif);
    run_test();
  end
endmodule
