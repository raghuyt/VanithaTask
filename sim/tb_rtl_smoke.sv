// Directed RTL smoke test. No UVM. Use this before the full regression
// to prove reset, ID, timeout, interrupt, and the fail-safe reset pulse.
`timescale 1ns/1ps

module tb_rtl_smoke;
  import fswwdt_pkg::*;

  logic pclk, wdt_clk;
  logic preset_n, wdt_rst_n;
  logic psel, penable, pwrite;
  logic [7:0]  paddr;
  logic [31:0] pwdata, prdata;
  logic pready, pslverr;
  logic wdt_irq, wdt_reset_req, wdt_fail_ind;
  int   errors;
  logic [31:0] rdata;

  fswwdt_top dut (
    .pclk(pclk), .preset_n(preset_n),
    .psel(psel), .penable(penable), .pwrite(pwrite),
    .paddr(paddr), .pwdata(pwdata), .prdata(prdata),
    .pready(pready), .pslverr(pslverr),
    .wdt_clk(wdt_clk), .wdt_rst_n(wdt_rst_n),
    .wdt_irq(wdt_irq), .wdt_reset_req(wdt_reset_req),
    .wdt_fail_ind(wdt_fail_ind)
  );

  initial begin
    pclk = 0;
    forever #5ns pclk = ~pclk;
  end
  initial begin
    wdt_clk = 0;
    forever #50ns wdt_clk = ~wdt_clk;
  end

  task automatic apb_write(input logic [7:0] addr, input logic [31:0] data);
    @(posedge pclk);
    psel <= 1'b1; penable <= 1'b0; pwrite <= 1'b1;
    paddr <= addr; pwdata <= data;
    @(posedge pclk);
    penable <= 1'b1;
    @(posedge pclk);
    psel <= 1'b0; penable <= 1'b0;
  endtask

  task automatic apb_read(input logic [7:0] addr, output logic [31:0] data);
    @(posedge pclk);
    psel <= 1'b1; penable <= 1'b0; pwrite <= 1'b0;
    paddr <= addr; pwdata <= '0;
    @(posedge pclk);
    penable <= 1'b1;
    @(posedge pclk);
    data = prdata;
    psel <= 1'b0; penable <= 1'b0;
  endtask

  initial begin
    errors = 0;
    preset_n = 0; wdt_rst_n = 0;
    psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;
    repeat (5) @(posedge pclk);
    preset_n = 1; wdt_rst_n = 1;
    repeat (5) @(posedge pclk);

    apb_read(ADDR_ID, rdata);
    if (rdata !== ID_VALUE) begin
      $error("smoke: ID 0x%08h", rdata);
      errors++;
    end

    apb_write(ADDR_CFG, 32'h0000_0010);
    apb_write(ADDR_ERRCNT, 32'h0000_0100);
    apb_write(ADDR_CTRL, 32'h0000_000D); // irq_en, rst_en, en

    fork
      begin
        wait (wdt_irq === 1'b1);
      end
      begin
        repeat (80) @(posedge wdt_clk);
        $error("smoke: timeout waiting for wdt_irq");
        errors++;
      end
    join_any
    disable fork;

    fork
      begin
        wait (wdt_reset_req === 1'b1 && wdt_fail_ind === 1'b1);
      end
      begin
        repeat (20) @(posedge wdt_clk);
        $error("smoke: timeout waiting for wdt_reset_req");
        errors++;
      end
    join_any
    disable fork;

    if (errors == 0)
      $display("SMOKE PASSED");
    else
      $display("SMOKE FAILED errors=%0d", errors);
    $finish;
  end
endmodule
