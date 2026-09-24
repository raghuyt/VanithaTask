class fswwdt_env extends uvm_env;
  `uvm_component_utils(fswwdt_env)

  fswwdt_agent       apb;
  fswwdt_wdt_agent   wdt;
  fswwdt_scoreboard  sb;
  fswwdt_coverage    cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb = fswwdt_agent::type_id::create("apb", this);
    wdt = fswwdt_wdt_agent::type_id::create("wdt", this);
    sb  = fswwdt_scoreboard::type_id::create("sb", this);
    cov = fswwdt_coverage::type_id::create("cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    apb.mon.ap.connect(sb.apb_imp);
    apb.mon.ap.connect(cov.apb_imp);
    wdt.mon.ap.connect(sb.wdt_imp);
    wdt.mon.ap.connect(cov.wdt_imp);
  endfunction
endclass
