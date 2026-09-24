class fswwdt_base_seq extends uvm_sequence #(fswwdt_seq_item);
  `uvm_object_utils(fswwdt_base_seq)

  virtual fswwdt_if vif;

  function new(string name = "fswwdt_base_seq");
    super.new(name);
  endfunction

  task pre_start();
    if (!uvm_config_db#(virtual fswwdt_if)::get(null, "*", "vif", vif))
      if (!uvm_config_db#(virtual fswwdt_if)::get(m_sequencer, "", "vif", vif))
        `uvm_fatal("NOVIF", "sequence did not get the virtual interface")
  endtask

  task automatic xfer(
    input  bit          is_write,
    input  bit [7:0]    addr,
    input  bit [31:0]   data,
    output bit [31:0]   rdata,
    output bit          slverr
  );
    fswwdt_seq_item tr;
    tr = fswwdt_seq_item::type_id::create("tr");
    start_item(tr);
    tr.write = is_write;
    tr.addr  = addr;
    tr.data  = data;
    finish_item(tr);
    rdata  = tr.rdata;
    slverr = tr.slverr;
  endtask

  task automatic apb_write(bit [7:0] addr, bit [31:0] data, bit exp_err = 1'b0);
    bit [31:0] rdata;
    bit        slverr;
    xfer(1'b1, addr, data, rdata, slverr);
    if (slverr !== exp_err)
      `uvm_error("APB", $sformatf(
        "write 0x%02h PSLVERR=%0b expected %0b", addr, slverr, exp_err))
  endtask

  task automatic apb_read(bit [7:0] addr, output bit [31:0] data, input bit exp_err = 1'b0);
    bit slverr;
    xfer(1'b0, addr, 32'h0, data, slverr);
    if (slverr !== exp_err)
      `uvm_error("APB", $sformatf(
        "read 0x%02h PSLVERR=%0b expected %0b", addr, slverr, exp_err))
  endtask

  task automatic do_reset(int cycles = 5);
    vif.wdt_clk_en = 1'b1;
    vif.preset_n   = 1'b0;
    vif.wdt_rst_n  = 1'b0;
    repeat (cycles) @(posedge vif.pclk);
    vif.preset_n  = 1'b1;
    vif.wdt_rst_n = 1'b1;
    repeat (cycles) @(posedge vif.pclk);
  endtask

  task automatic arm(
    bit [15:0] to_val,
    bit [1:0]  win_sel,
    bit        win_en,
    bit        irq_en,
    bit        rst_en,
    bit [7:0]  thresh,
    bit        lock_it = 1'b0
  );
    apb_write(fswwdt_pkg::ADDR_CFG, {14'd0, win_sel, to_val});
    apb_write(fswwdt_pkg::ADDR_ERRCNT, {16'd0, thresh, 8'd0});
    apb_write(fswwdt_pkg::ADDR_CTRL,
              {27'd0, lock_it, rst_en, irq_en, win_en, 1'b1});
  endtask

  task automatic wait_running(int polls = 50);
    bit [31:0] r;
    repeat (polls) begin
      apb_read(fswwdt_pkg::ADDR_STAT, r);
      if (r[0] === 1'b1)
        return;
      repeat (4) @(posedge vif.pclk);
    end
    `uvm_error("RUN", "STAT.RUNNING did not set")
  endtask

  task automatic wait_pin(input string name, output bit got, input int n, input bit is_reset);
    got = 1'b0;
    fork
      begin
        fork
          begin
            if (is_reset)
              wait (vif.wdt_reset_req === 1'b1);
            else
              wait (vif.wdt_irq === 1'b1);
            got = 1'b1;
          end
          begin
            repeat (n) @(posedge vif.wdt_clk);
          end
        join_any
        disable fork;
      end
    join
    if (!got)
      `uvm_error("PIN", $sformatf("timed out waiting for %s", name))
  endtask

  task automatic wait_irq(int n, output bit got);
    wait_pin("wdt_irq", got, n, 1'b0);
  endtask

  task automatic wait_reset_pin(int n = 80);
    bit got;
    wait_pin("wdt_reset_req", got, n, 1'b1);
  endtask

  task automatic wait_irq_low(int n = 40);
    bit fell;
    fell = 1'b0;
    fork
      begin
        fork
          begin
            wait (vif.wdt_irq === 1'b0);
            fell = 1'b1;
          end
          begin
            repeat (n) @(posedge vif.wdt_clk);
          end
        join_any
        disable fork;
      end
    join
    if (!fell)
      `uvm_error("IRQ", "wdt_irq did not clear")
  endtask

  task automatic expect_no_irq(int n);
    repeat (n) begin
      @(posedge vif.wdt_clk);
      if (vif.wdt_irq === 1'b1) begin
        `uvm_error("IRQ", "wdt_irq asserted too early")
        return;
      end
    end
  endtask
endclass

class fswwdt_reg_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_reg_seq)
  function new(string name = "fswwdt_reg_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] r;
    bit [7:0]  addrs[$];

    apb_read(fswwdt_pkg::ADDR_ID, r);
    if (r !== fswwdt_pkg::ID_VALUE)
      `uvm_error("REG", $sformatf("ID 0x%08h", r))

    apb_read(fswwdt_pkg::ADDR_CTRL, r);
    if (r !== 32'h0000_000C)
      `uvm_error("REG", $sformatf("CTRL reset 0x%08h", r))

    apb_read(fswwdt_pkg::ADDR_CFG, r);
    if (r !== 32'h0000_0100)
      `uvm_error("REG", $sformatf("CFG reset 0x%08h", r))

    // Clamps: timeout 0 becomes 2, threshold 0 becomes 1.
    apb_write(fswwdt_pkg::ADDR_CFG, 32'h0);
    apb_read(fswwdt_pkg::ADDR_CFG, r);
    if (r[15:0] !== 16'd2)
      `uvm_error("REG", $sformatf("TO_VAL clamp 0x%0h", r[15:0]))

    apb_write(fswwdt_pkg::ADDR_ERRCNT, 32'h0);
    apb_read(fswwdt_pkg::ADDR_ERRCNT, r);
    if (r[15:8] !== 8'd1)
      `uvm_error("REG", "threshold clamp failed")

    apb_write(fswwdt_pkg::ADDR_CFG, 32'h0001_0020);
    apb_read(fswwdt_pkg::ADDR_CFG, r);
    if (r !== 32'h0001_0020)
      `uvm_error("REG", "CFG readback")

    // Enable then disable while the default-sized window cannot expire yet.
    apb_write(fswwdt_pkg::ADDR_CFG, 32'h0000_0100);
    apb_write(fswwdt_pkg::ADDR_CTRL, 32'h0000_000F);
    apb_read(fswwdt_pkg::ADDR_CTRL, r);
    if (r !== 32'h0000_000F)
      `uvm_error("REG", "CTRL enable readback")
    apb_write(fswwdt_pkg::ADDR_CTRL, 32'h0000_000C);

    // Lock rejects CFG until both unlock keys are written.
    apb_write(fswwdt_pkg::ADDR_CTRL, 32'h0000_001C);
    apb_write(fswwdt_pkg::ADDR_CFG, 32'h0000_0040, 1'b1);
    apb_read(fswwdt_pkg::ADDR_CFG, r);
    if (r !== 32'h0000_0100)
      `uvm_error("REG", "locked CFG changed")

    apb_write(fswwdt_pkg::ADDR_UNLOCK, 32'h1111_1111);
    apb_write(fswwdt_pkg::ADDR_UNLOCK, fswwdt_pkg::UNLOCK_KEY2);
    apb_write(fswwdt_pkg::ADDR_CFG, 32'h0000_0040, 1'b1);

    apb_write(fswwdt_pkg::ADDR_UNLOCK, fswwdt_pkg::UNLOCK_KEY1);
    apb_write(fswwdt_pkg::ADDR_UNLOCK, fswwdt_pkg::UNLOCK_KEY2);
    apb_write(fswwdt_pkg::ADDR_CFG, 32'h0000_0030);
    apb_read(fswwdt_pkg::ADDR_CFG, r);
    if (r !== 32'h0000_0030)
      `uvm_error("REG", "unlock did not open CFG")

    apb_write(fswwdt_pkg::ADDR_SRV, 32'h0000_0001);
    apb_read(fswwdt_pkg::ADDR_STAT, r);
    if (r[6] !== 1'b1)
      `uvm_error("REG", "bad service key did not set STAT.BAD_SRV")
    apb_write(fswwdt_pkg::ADDR_INTCLR, 32'h1);
    apb_read(fswwdt_pkg::ADDR_STAT, r);
    if (r[6] !== 1'b0)
      `uvm_error("REG", "INTCLR did not clear BAD_SRV")

    apb_read(fswwdt_pkg::ADDR_SRV, r);
    apb_read(fswwdt_pkg::ADDR_UNLOCK, r);
    apb_read(fswwdt_pkg::ADDR_INTCLR, r);
    apb_write(fswwdt_pkg::ADDR_ID, 32'hFFFF_FFFF, 1'b1);
    apb_read(fswwdt_pkg::ADDR_ID, r);

    apb_write(8'h20, 32'h1, 1'b1);
    apb_read(8'h20, r, 1'b1);
    apb_write(8'h01, 32'h1, 1'b1);
    apb_read(8'h02, r, 1'b1);

    addrs = '{8'h00, 8'h04, 8'h08, 8'h0C, 8'h10, 8'h14, 8'h18, 8'h1C};
    foreach (addrs[i])
      apb_read(addrs[i], r);
  endtask
endclass

class fswwdt_basic_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_basic_seq)
  function new(string name = "fswwdt_basic_seq");
    super.new(name);
  endfunction

  task body();
    bit got;
    // Classic mode: a legal pet reloads the counter. Three pets must not IRQ.
    arm(16'd40, 2'b00, 1'b0, 1'b1, 1'b0, 8'd3);
    wait_running();
    repeat (3) begin
      repeat (12) @(posedge vif.wdt_clk);
      apb_write(fswwdt_pkg::ADDR_SRV, fswwdt_pkg::SRV_KEY);
      expect_no_irq(10);
    end
    wait_irq(80, got);
  endtask
endclass

class fswwdt_window_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_window_seq)
  function new(string name = "fswwdt_window_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] r;
    bit got;
    // 25% open point, timeout 64. Service after 24 counts is inside the window.
    arm(16'd64, 2'b01, 1'b1, 1'b1, 1'b0, 8'd5);
    wait_running();
    repeat (24) @(posedge vif.wdt_clk);
    apb_write(fswwdt_pkg::ADDR_SRV, fswwdt_pkg::SRV_KEY);
    repeat (20) @(posedge vif.wdt_clk);
    apb_read(fswwdt_pkg::ADDR_STAT, r);
    if (r[3] === 1'b1 || r[2] === 1'b1)
      `uvm_error("WIN", $sformatf("in-window service flagged fault STAT=0x%08h", r))
    wait_irq(120, got);
  endtask
endclass

class fswwdt_timeout_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_timeout_seq)
  function new(string name = "fswwdt_timeout_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] r;
    bit got;
    arm(16'd32, 2'b00, 1'b0, 1'b1, 1'b0, 8'd4);
    wait_running();
    expect_no_irq(8);
    wait_irq(70, got);
    repeat (8) @(posedge vif.pclk);
    apb_read(fswwdt_pkg::ADDR_STAT, r);
    if (r[2] !== 1'b1)
      `uvm_error("TO", $sformatf("TO_ERR not set STAT=0x%08h", r))
  endtask
endclass

class fswwdt_early_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_early_seq)
  function new(string name = "fswwdt_early_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] r;
    bit got;
    // 50% of 128 counts is still closed when RUNNING is first observed.
    arm(16'd128, 2'b00, 1'b1, 1'b1, 1'b0, 8'd5);
    wait_running();
    apb_write(fswwdt_pkg::ADDR_SRV, fswwdt_pkg::SRV_KEY);
    wait_irq(60, got);
    repeat (6) @(posedge vif.pclk);
    apb_read(fswwdt_pkg::ADDR_STAT, r);
    if (r[3] !== 1'b1)
      `uvm_error("EARLY", $sformatf("EARLY_ERR not set STAT=0x%08h", r))
    if (vif.wdt_reset_req === 1'b1)
      `uvm_error("EARLY", "reset requested below the error threshold")
  endtask
endclass

class fswwdt_late_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_late_seq)
  function new(string name = "fswwdt_late_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] r;
    bit got;
    // No pet in the open window. The fault must be a timeout, not an early kick.
    arm(16'd36, 2'b00, 1'b1, 1'b1, 1'b0, 8'd4);
    wait_running();
    wait_irq(80, got);
    repeat (8) @(posedge vif.pclk);
    apb_read(fswwdt_pkg::ADDR_STAT, r);
    if (r[2] !== 1'b1 || r[3] === 1'b1)
      `uvm_error("LATE", $sformatf("expected timeout only, STAT=0x%08h", r))
  endtask
endclass

class fswwdt_irq_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_irq_seq)
  function new(string name = "fswwdt_irq_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] r;
    bit got;
    arm(16'd28, 2'b00, 1'b0, 1'b0, 1'b0, 8'd4);
    wait_running();
    repeat (50) @(posedge vif.wdt_clk);
    if (vif.wdt_irq === 1'b1)
      `uvm_error("IRQ", "irq pin high while irq_en=0")
    apb_read(fswwdt_pkg::ADDR_STAT, r);
    if (r[2] !== 1'b1)
      `uvm_error("IRQ", "timeout flag missing while irq is masked")

    do_reset();
    arm(16'd28, 2'b00, 1'b0, 1'b1, 1'b0, 8'd4);
    wait_running();
    wait_irq(70, got);
    apb_write(fswwdt_pkg::ADDR_INTCLR, 32'h1);
    wait_irq_low(40);
  endtask
endclass

class fswwdt_reset_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_reset_seq)
  function new(string name = "fswwdt_reset_seq");
    super.new(name);
  endfunction

  task body();
    bit got;
    int i;
    // One fault is fatal when the threshold is 1.
    arm(16'd24, 2'b00, 1'b0, 1'b1, 1'b1, 8'd1);
    wait_running();
    wait_irq(60, got);
    wait_reset_pin(30);
    if (vif.wdt_fail_ind !== 1'b1)
      `uvm_error("RST", "fail indicator did not stick")

    do_reset();
    // Three early pets: IRQ on the first two, reset on the third.
    arm(16'd256, 2'b00, 1'b1, 1'b1, 1'b1, 8'd3);
    wait_running();
    for (i = 0; i < 3; i++) begin
      apb_write(fswwdt_pkg::ADDR_SRV, fswwdt_pkg::SRV_KEY);
      wait_irq(80, got);
      if (i < 2) begin
        if (vif.wdt_reset_req === 1'b1)
          `uvm_error("RST", "reset before the error threshold")
        apb_write(fswwdt_pkg::ADDR_INTCLR, 32'h1);
        wait_irq_low(40);
      end
    end
    wait_reset_pin(20);
  endtask
endclass

class fswwdt_err_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_err_seq)
  function new(string name = "fswwdt_err_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] r;
    bit got;
    arm(16'd32, 2'b00, 1'b0, 1'b1, 1'b0, 8'd4);
    wait_running();
    apb_write(fswwdt_pkg::ADDR_SRV, 32'hDEAD_BEEF);
    apb_read(fswwdt_pkg::ADDR_STAT, r);
    if (r[6] !== 1'b1)
      `uvm_error("ERR", "wrong key was treated as a service")
    // The bad write must not reload the counter: the timeout still arrives.
    wait_irq(70, got);
  endtask
endclass

class fswwdt_por_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_por_seq)
  function new(string name = "fswwdt_por_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] r;
    if (vif.wdt_irq !== 1'b0 || vif.wdt_reset_req !== 1'b0 || vif.wdt_fail_ind !== 1'b0)
      `uvm_error("POR", "outputs not idle after power-on reset")
    apb_read(fswwdt_pkg::ADDR_ID, r);
    apb_read(fswwdt_pkg::ADDR_STAT, r);
    if (r[0] !== 1'b0)
      `uvm_error("POR", "RUNNING set before enable")
  endtask
endclass

class fswwdt_warm_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_warm_seq)
  function new(string name = "fswwdt_warm_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] r;
    bit got;
    arm(16'd40, 2'b00, 1'b0, 1'b1, 1'b0, 8'd4);
    wait_running();
    do_reset();
    if (vif.wdt_irq !== 1'b0)
      `uvm_error("WARM", "irq survived a full warm reset")
    apb_read(fswwdt_pkg::ADDR_CTRL, r);
    if (r !== 32'h0000_000C)
      `uvm_error("WARM", "CTRL was not returned to reset")
    apb_read(fswwdt_pkg::ADDR_STAT, r);
    if (r[0] !== 1'b0)
      `uvm_error("WARM", "core still running after wdt_rst_n")
    arm(16'd24, 2'b00, 1'b0, 1'b1, 1'b0, 8'd4);
    wait_running();
    wait_irq(60, got);
  endtask
endclass

class fswwdt_async_rst_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_async_rst_seq)
  function new(string name = "fswwdt_async_rst_seq");
    super.new(name);
  endfunction

  task body();
    bit got;
    arm(16'd20, 2'b00, 1'b0, 1'b1, 1'b1, 8'd1);
    wait_running();
    wait_irq(50, got);
    @(posedge vif.pclk);
    #3ns;
    vif.preset_n  = 1'b0;
    vif.wdt_rst_n = 1'b0;
    #30ns;
    if (vif.wdt_irq !== 1'b0 || vif.wdt_reset_req !== 1'b0 || vif.wdt_fail_ind !== 1'b0)
      `uvm_error("ARST", "outputs not cleared by async reset")
    vif.preset_n  = 1'b1;
    vif.wdt_rst_n = 1'b1;
    repeat (5) @(posedge vif.pclk);
  endtask
endclass

class fswwdt_sync_rst_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_sync_rst_seq)
  function new(string name = "fswwdt_sync_rst_seq");
    super.new(name);
  endfunction

  task body();
    bit got;
    arm(16'd20, 2'b00, 1'b0, 1'b1, 1'b1, 8'd1);
    wait_running();
    wait_irq(50, got);
    @(posedge vif.wdt_clk);
    vif.wdt_rst_n <= 1'b0;
    @(posedge vif.pclk);
    vif.preset_n <= 1'b0;
    repeat (4) @(posedge vif.wdt_clk);
    if (vif.wdt_irq !== 1'b0 || vif.wdt_reset_req !== 1'b0)
      `uvm_error("SRST", "sync reset did not clear the watchdog outputs")
    @(posedge vif.wdt_clk);
    vif.wdt_rst_n <= 1'b1;
    @(posedge vif.pclk);
    vif.preset_n <= 1'b1;
    repeat (5) @(posedge vif.pclk);
  endtask
endclass

class fswwdt_clk_stop_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_clk_stop_seq)
  function new(string name = "fswwdt_clk_stop_seq");
    super.new(name);
  endfunction

  task body();
    bit got;
    arm(16'd20, 2'b00, 1'b0, 1'b1, 1'b0, 8'd4);
    wait_running();
    @(negedge vif.wdt_clk);
    vif.wdt_clk_en = 1'b0;
    // Longer than the programmed timeout. An IRQ here means the counter
    // kept running without wdt_clk.
    repeat (400) @(posedge vif.pclk);
    if (vif.wdt_irq === 1'b1)
      `uvm_error("CLK", "irq while wdt_clk was stopped")
    vif.wdt_clk_en = 1'b1;
    repeat (4) @(posedge vif.pclk);
    wait_irq(60, got);
  endtask
endclass

class fswwdt_freq_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_freq_seq)
  function new(string name = "fswwdt_freq_seq");
    super.new(name);
  endfunction

  task body();
    realtime t0, t1, period, dt;
    bit got;
    @(posedge vif.wdt_clk);
    t0 = $realtime;
    @(posedge vif.wdt_clk);
    period = $realtime - t0;
    if (period <= 0)
      `uvm_fatal("FREQ", "could not measure wdt_clk")
    arm(16'd32, 2'b00, 1'b0, 1'b1, 1'b0, 8'd4);
    wait_running();
    t0 = $realtime;
    wait_irq(90, got);
    t1 = $realtime;
    dt = t1 - t0;
    // RUNNING is observed a few counts after the counter leaves IDLE,
    // and the service CDC is not in this path. Half a window to a bit
    // over two windows absorbs that uncertainty at any wdt_clk period.
    if (dt < (16 * period) || dt > (80 * period))
      `uvm_error("FREQ", $sformatf(
        "irq delay %.1f ns, period %.1f ns", dt, period))
    else
      `uvm_info("FREQ", $sformatf("irq delay %.1f ns at period %.1f ns", dt, period), UVM_LOW)
  endtask
endclass

class fswwdt_rst_during_run_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_rst_during_run_seq)
  function new(string name = "fswwdt_rst_during_run_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] r;
    bit got;
    arm(16'd48, 2'b00, 1'b0, 1'b1, 1'b0, 8'd4);
    wait_running();

    // Bus reset must not silence a watchdog that is already running.
    vif.preset_n = 1'b0;
    repeat (4) @(posedge vif.pclk);
    vif.preset_n = 1'b1;
    repeat (8) @(posedge vif.pclk);
    apb_read(fswwdt_pkg::ADDR_CTRL, r);
    if (r[0] !== 1'b0)
      `uvm_error("PRESET", "CTRL.EN survived preset_n; regs should clear")
    apb_read(fswwdt_pkg::ADDR_STAT, r);
    if (r[0] !== 1'b1)
      `uvm_error("PRESET", "core stopped on preset_n alone")

    // Watchdog-domain reset clears the core, then the register file is
    // pushed again. CTRL was cleared by preset, so the reload disables it.
    vif.wdt_rst_n = 1'b0;
    repeat (4) @(posedge vif.wdt_clk);
    vif.wdt_rst_n = 1'b1;
    repeat (20) @(posedge vif.wdt_clk);
    apb_read(fswwdt_pkg::ADDR_STAT, r);
    if (r[0] !== 1'b0)
      `uvm_error("WRST", "core still running after wdt_rst_n with EN=0")

    arm(16'd24, 2'b00, 1'b0, 1'b1, 1'b0, 8'd4);
    wait_running();
    wait_irq(60, got);
  endtask
endclass

class fswwdt_rst_during_to_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_rst_during_to_seq)
  function new(string name = "fswwdt_rst_during_to_seq");
    super.new(name);
  endfunction

  task body();
    bit got;
    arm(16'd24, 2'b00, 1'b0, 1'b1, 1'b0, 8'd4);
    wait_running();
    wait_irq(60, got);
    vif.wdt_rst_n = 1'b0;
    repeat (3) @(posedge vif.wdt_clk);
    if (vif.wdt_irq !== 1'b0)
      `uvm_error("TO_RST", "irq stayed high through wdt_rst_n")
    vif.wdt_rst_n = 1'b1;
    // EN is still 1 in the register file, so release reloads and arms again.
    wait_running();
    wait_irq_low(10);
    wait_irq(70, got);
  endtask
endclass

class fswwdt_cov_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_cov_seq)
  function new(string name = "fswwdt_cov_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] r;
    bit got;
    bit [1:0] sel;
    for (int s = 0; s < 4; s++) begin
      sel = s[1:0];
      do_reset();
      arm(16'd256, sel, 1'b1, 1'b1, 1'b0, 8'd5);
      wait_running();
      apb_write(fswwdt_pkg::ADDR_SRV, fswwdt_pkg::SRV_KEY);
      wait_irq(80, got);
      apb_read(fswwdt_pkg::ADDR_STAT, r);

      do_reset();
      arm(16'd24, sel, 1'b1, 1'b1, 1'b0, 8'd5);
      wait_running();
      wait_irq(60, got);
      apb_read(fswwdt_pkg::ADDR_STAT, r);
    end
    // Large timeout bin, both enable polarities, and a reset event.
    apb_write(fswwdt_pkg::ADDR_CFG, {14'd0, 2'b00, 16'd256});
    apb_write(fswwdt_pkg::ADDR_CTRL, 32'h0000_000E); // win_en, irq, rst, en=0
    do_reset();
    arm(16'd20, 2'b00, 1'b0, 1'b1, 1'b1, 8'd1);
    wait_running();
    wait_reset_pin(50);
    apb_read(fswwdt_pkg::ADDR_STAT, r);
  endtask
endclass

class fswwdt_rand_seq extends fswwdt_base_seq;
  `uvm_object_utils(fswwdt_rand_seq)
  function new(string name = "fswwdt_rand_seq");
    super.new(name);
  endfunction

  task body();
    fswwdt_seq_item tr;
    repeat (80) begin
      tr = fswwdt_seq_item::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with {
        addr[1:0] == 2'b00;
        addr dist { [8'h00:8'h1C] :/ 8, 8'h20 :/ 1, 8'h24 :/ 1 };
      })
        `uvm_fatal("RAND", "randomize failed")
      finish_item(tr);
    end
  endtask
endclass
