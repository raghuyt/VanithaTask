// ----------------------------------------------------------------------------
// FSWWDT bench interface.
// pclk / wdt_clk are generated in tb_top. Resets and PSEL are driven from
// the test and the APB driver. wdt_clk_en gates the watchdog clock in the
// harness so the clock-stop test does not need a second DUT pin.
// ----------------------------------------------------------------------------
interface fswwdt_if (
  input logic pclk,
  input logic wdt_clk
);
  logic        preset_n       = 1'b0;
  logic        wdt_rst_n      = 1'b0;
  logic        wdt_clk_en     = 1'b1;
  logic        psel           = 1'b0;
  logic        penable        = 1'b0;
  logic        pwrite         = 1'b0;
  logic [7:0]  paddr          = '0;
  logic [31:0] pwdata         = '0;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;
  logic        wdt_irq;
  logic        wdt_reset_req;
  logic        wdt_fail_ind;

  // Access phase is only legal when the select from the setup phase is still on.
  a_apb_penable: assert property (
    @(posedge pclk) disable iff (preset_n !== 1'b1)
      penable |-> psel
  ) else $error("APB: PENABLE high while PSEL is low");

  a_apb_setup_to_access: assert property (
    @(posedge pclk) disable iff (preset_n !== 1'b1)
      (psel && !penable) |=> (psel && penable)
  ) else $error("APB: setup phase was not followed by an access phase");

  // A slave error is only meaningful in the access phase.
  a_apb_slverr_phase: assert property (
    @(posedge pclk) disable iff (preset_n !== 1'b1)
      pslverr |-> (psel && penable)
  ) else $error("APB: PSLVERR outside the access phase");
endinterface
