// Shadow of fswwdt_regs.sv. Keep the accept / PSLVERR / unlock rules aligned
// with the RTL. Watchdog-domain status bits are not predicted here.
class fswwdt_reg_model extends uvm_object;
  `uvm_object_utils(fswwdt_reg_model)

  bit               en, win_en, irq_en, rst_en, lock, bad_srv;
  bit [1:0]         win_sel;
  bit [15:0]        to_val;
  bit [7:0]         err_thresh;
  bit [1:0]         ul; // 0 idle, 1 saw key1, 2 open

  function new(string name = "fswwdt_reg_model");
    super.new(name);
    reset();
  endfunction

  function void reset();
    en         = 1'b0;
    win_en     = 1'b0;
    irq_en     = 1'b1;
    rst_en     = 1'b1;
    lock       = 1'b0;
    bad_srv    = 1'b0;
    win_sel    = 2'b00;
    to_val     = fswwdt_pkg::TO_VAL_RESET;
    err_thresh = fswwdt_pkg::THRESH_RESET;
    ul         = 2'd0;
  endfunction

  // Returns the PSLVERR the RTL must produce, and updates the shadow if the
  // write is accepted.
  function bit predict_write(bit [7:0] addr, bit [31:0] data);
    bit mapped;
    bit locked;
    bit exp_slverr;

    mapped = fswwdt_pkg::addr_mapped(addr);
    locked = lock && (ul != 2'd2) && fswwdt_pkg::addr_protected(addr);
    exp_slverr = (!mapped) || (addr == fswwdt_pkg::ADDR_ID) || locked;

    if (mapped && (addr == fswwdt_pkg::ADDR_UNLOCK)) begin
      if (ul == 2'd0)
        ul = (data == fswwdt_pkg::UNLOCK_KEY1) ? 2'd1 : 2'd0;
      else if (ul == 2'd1)
        ul = (data == fswwdt_pkg::UNLOCK_KEY2) ? 2'd2 : 2'd0;
      else
        ul = (data == fswwdt_pkg::UNLOCK_KEY1) ? 2'd1 : 2'd0;
      return 1'b0;
    end

    if (ul == 2'd1)
      ul = 2'd0;

    if (!exp_slverr && mapped) begin
      case (addr)
        fswwdt_pkg::ADDR_CTRL: begin
          en     = data[0];
          win_en = data[1];
          irq_en = data[2];
          rst_en = data[3];
          lock   = data[4];
          if (ul == 2'd2)
            ul = 2'd0;
        end
        fswwdt_pkg::ADDR_CFG: begin
          to_val  = (data[15:0] < fswwdt_pkg::TO_VAL_MIN)
                    ? fswwdt_pkg::TO_VAL_MIN : data[15:0];
          win_sel = data[17:16];
          if (ul == 2'd2)
            ul = 2'd0;
        end
        fswwdt_pkg::ADDR_ERRCNT: begin
          err_thresh = (data[15:8] == 8'h00) ? 8'd1 : data[15:8];
          if (ul == 2'd2)
            ul = 2'd0;
        end
        fswwdt_pkg::ADDR_SRV: begin
          if (data != fswwdt_pkg::SRV_KEY)
            bad_srv = 1'b1;
        end
        fswwdt_pkg::ADDR_INTCLR: begin
          if (data[0])
            bad_srv = 1'b0;
        end
        default: begin
        end
      endcase
    end
    return exp_slverr;
  endfunction
endclass
