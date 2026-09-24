// ----------------------------------------------------------------------------
// APB register file, unlock sequencer, and config-push control.
// Protected registers (CTRL, CFG, ERRCNT) are ignored with PSLVERR while
// LOCK=1 unless the two-key UNLOCK sequence has opened a one-write window.
// Service, interrupt clear, and unlock remain legal while locked: software
// must still be able to pet the dog after the boot code locks the IP.
// ----------------------------------------------------------------------------
`default_nettype none

module fswwdt_regs (
  input  logic                          pclk,
  input  logic                          rst_n,
  input  logic                          psel,
  input  logic                          penable,
  input  logic                          pwrite,
  input  logic [fswwdt_pkg::ADDR_W-1:0] paddr,
  input  logic [fswwdt_pkg::DATA_W-1:0] pwdata,
  output logic [fswwdt_pkg::DATA_W-1:0] prdata,
  output logic                          pready,
  output logic                          pslverr,

  // Level of wdt_rst_n, synchronized into pclk. A real 0->1 after the
  // synchronizer has already observed a 1 reloads the core from this file.
  input  logic                          wdt_rst_lvl,

  output logic                          cfg_push,
  output logic [fswwdt_pkg::DATA_W-1:0] cfg_bus,
  output logic                          srv_evt,
  output logic                          irq_clr_evt,
  output logic                          rst_clr_evt,

  input  logic                          running,
  input  logic                          win_open,
  input  logic                          to_err,
  input  logic                          early_err,
  input  logic                          irq_pend,
  input  logic                          rst_pend,
  input  logic                          fail_ind,
  input  logic [7:0]                    err_cnt,
  input  logic                          srv_lost
);
  import fswwdt_pkg::*;

  typedef enum logic [1:0] {
    UL_IDLE,
    UL_STEP1,
    UL_OPEN
  } ul_st_e;

  logic        en, win_en, irq_en, rst_en, lock, bad_srv;
  logic [1:0]  win_sel;
  logic [CNT_W-1:0] to_val;
  logic [7:0]  err_thresh;
  ul_st_e      ul;

  logic        wdt_rst_seen;
  logic        reload_armed;

  logic        mapped;
  logic        locked_wr;
  logic        access_err;
  cfg_snap_t   snap;

  assign mapped    = addr_mapped(paddr);
  assign locked_wr = pwrite && lock && (ul != UL_OPEN) && addr_protected(paddr);
  assign access_err = (psel && penable) &&
                      (!mapped || (pwrite && (paddr == ADDR_ID)) || locked_wr);

  assign pready  = 1'b1;
  assign pslverr = access_err;

  always_comb begin
    snap.rsvd       = 2'b00;
    snap.err_thresh = err_thresh;
    snap.to_val     = to_val;
    snap.win_sel    = win_sel;
    snap.rst_en     = rst_en;
    snap.irq_en     = irq_en;
    snap.win_en     = win_en;
    snap.en         = en;
  end
  assign cfg_bus = snap;

  always_ff @(posedge pclk or negedge rst_n) begin
    if (!rst_n) begin
      en            <= 1'b0;
      win_en        <= 1'b0;
      irq_en        <= 1'b1;
      rst_en        <= 1'b1;
      lock          <= 1'b0;
      to_val        <= TO_VAL_RESET;
      win_sel       <= 2'b00;
      err_thresh    <= THRESH_RESET;
      bad_srv       <= 1'b0;
      ul            <= UL_IDLE;
      cfg_push      <= 1'b0;
      srv_evt       <= 1'b0;
      irq_clr_evt   <= 1'b0;
      rst_clr_evt   <= 1'b0;
      wdt_rst_seen  <= 1'b0;
      reload_armed  <= 1'b0;
    end else begin
      cfg_push    <= 1'b0;
      srv_evt     <= 1'b0;
      irq_clr_evt <= 1'b0;
      rst_clr_evt <= 1'b0;

      // Arm on the first observed 1 so the synchronizer's own reset
      // release does not push the freshly cleared register file into a
      // core that is supposed to survive preset_n.
      wdt_rst_seen <= wdt_rst_lvl;
      if (!reload_armed) begin
        if (wdt_rst_lvl)
          reload_armed <= 1'b1;
      end else if (wdt_rst_lvl && !wdt_rst_seen) begin
        cfg_push <= 1'b1;
      end

      if (psel && penable && pwrite) begin
        if (mapped && (paddr == ADDR_UNLOCK)) begin
          case (ul)
            UL_IDLE:  ul <= (pwdata == UNLOCK_KEY1) ? UL_STEP1 : UL_IDLE;
            UL_STEP1: ul <= (pwdata == UNLOCK_KEY2) ? UL_OPEN  : UL_IDLE;
            UL_OPEN:  ul <= (pwdata == UNLOCK_KEY1) ? UL_STEP1 : UL_IDLE;
            default:  ul <= UL_IDLE;
          endcase
        end else begin
          if (ul == UL_STEP1)
            ul <= UL_IDLE;

          if (mapped && (paddr != ADDR_ID) && !locked_wr) begin
            case (paddr)
              ADDR_CTRL: begin
                en      <= pwdata[0];
                win_en  <= pwdata[1];
                irq_en  <= pwdata[2];
                rst_en  <= pwdata[3];
                lock    <= pwdata[4];
                cfg_push <= 1'b1;
                if (ul == UL_OPEN)
                  ul <= UL_IDLE;
              end
              ADDR_CFG: begin
                to_val  <= (pwdata[15:0] < TO_VAL_MIN) ? TO_VAL_MIN : pwdata[15:0];
                win_sel <= pwdata[17:16];
                cfg_push <= 1'b1;
                if (ul == UL_OPEN)
                  ul <= UL_IDLE;
              end
              ADDR_ERRCNT: begin
                err_thresh <= (pwdata[15:8] == 8'h00) ? 8'd1 : pwdata[15:8];
                cfg_push   <= 1'b1;
                if (ul == UL_OPEN)
                  ul <= UL_IDLE;
              end
              ADDR_SRV: begin
                if (pwdata == SRV_KEY)
                  srv_evt <= 1'b1;
                else
                  bad_srv <= 1'b1;
              end
              ADDR_INTCLR: begin
                if (pwdata[0]) begin
                  irq_clr_evt <= 1'b1;
                  bad_srv     <= 1'b0;
                end
                if (pwdata[1])
                  rst_clr_evt <= 1'b1;
              end
              default: begin
              end
            endcase
          end
        end
      end
    end
  end

  always_comb begin
    prdata = '0;
    if (psel && penable && !pwrite && mapped && !access_err) begin
      case (paddr)
        ADDR_CTRL: prdata = {27'd0, lock, rst_en, irq_en, win_en, en};
        ADDR_CFG:  prdata = {14'd0, win_sel, to_val};
        ADDR_STAT: prdata = {21'd0, srv_lost, (ul == UL_OPEN), fail_ind,
                             lock, bad_srv, rst_pend, irq_pend,
                             early_err, to_err, win_open, running};
        ADDR_ERRCNT: prdata = {16'd0, err_thresh, err_cnt};
        ADDR_ID: prdata = ID_VALUE;
        default: prdata = '0;
      endcase
    end
  end
endmodule

`default_nettype wire
