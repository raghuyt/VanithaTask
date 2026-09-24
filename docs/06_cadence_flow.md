# 6. Cadence flow

Run these on the Linux host where Xcelium is installed. This workspace was created on Windows and was not simulated here. From `sim/`:

```bash
make smoke
make sim TEST=fswwdt_basic_test
make regress
```

`make help` lists the targets. `sim/run_regress.sh` is the same regression if you call bash directly.

If the scripts were copied from Windows and fail with `$'\r'`, run `dos2unix Makefile run_regress.sh`.

## Compile and elaborate

`xrun` compiles, elaborates, and simulates in one invocation. The UVM file list is `sim/filelist_uvm.f`. The macro `FSWWDT_ASSERT` turns on `fswwdt_sva`.

```bash
xrun -64bit -sv -timescale 1ns/1ps -access +rwc -licqueue \
  -uvm +define+FSWWDT_ASSERT +UVM_NO_RELNOTES \
  -f filelist_uvm.f \
  +UVM_TESTNAME=fswwdt_basic_test +WDT_CLK_NS=100 \
  -l logs/fswwdt_basic_test.log
```

`-uvm` picks up the UVM packaged with Xcelium. Add `-uvmhome $UVM_HOME` only if your site keeps UVM elsewhere. Some sites still want `-uvmhome CDNS-1.2`.

Synthesis and a non-assertion compile use `sim/filelist_rtl.f` and do not set `FSWWDT_ASSERT`.

RTL-only smoke, no UVM:

```bash
xrun -64bit -sv -timescale 1ns/1ps -access +rwc \
  +define+FSWWDT_ASSERT -f filelist_smoke.f -top tb_rtl_smoke
```

Expect `SMOKE PASSED`.

## Simulation

A passing UVM test ends with `TEST PASSED` and a `UVM_ERROR` count of 0. `UVM_FATAL` or a missing banner is a fail. The regress target greps the log so a clean `xrun` exit code is not treated as a pass by itself.

Useful plusargs:

| Plusarg | Effect |
| --- | --- |
| `+UVM_TESTNAME=<test>` | Which `uvm_test` to run |
| `+WDT_CLK_NS=40` | Watchdog period in ns. Default 100. `pclk` stays 10 ns |
| `+UVM_VERBOSITY=UVM_HIGH` | Driver/monitor detail |
| `+DUMP` | Writes `fswwdt.vcd` |

## SimVision

Interactive debug:

```bash
xrun -64bit -sv -uvm -access +rwc -timescale 1ns/1ps \
  +define+FSWWDT_ASSERT -f filelist_uvm.f \
  +UVM_TESTNAME=fswwdt_early_test -gui
```

In the Design Browser open `tb_top.dut.u_core`. The signals that explain a failure are `state`, `count`, `err_cnt`, `early_pulse`, `to_pulse`, `valid_srv`, `irq`, and `reset_req`. On `tb_top.vif`, look at `psel`, `penable`, `paddr`, `pwdata`, `prdata`, `pslverr`.

VCD from `make waves` opens with SimVision as well: **File → Open Database → fswwdt.vcd**.

To drop an SHM database from the SimVision console after `-gui` has elaborated:

```tcl
database -open waves -shm -into waves.shm
probe -create tb_top -all -depth all -database waves
run
```

Then later:

```bash
simvision waves.shm
```

## Coverage

Single test:

```bash
make cov TEST=fswwdt_cov_fill_test
```

Regression writes one `cov_work` test per `UVM_TESTNAME` (`-covtest` plus `-covoverwrite`). Merge:

```bash
make merge
```

That runs `imc -exec cov_merge.tcl` and writes `docs/cov_summary.txt` and `docs/cov_functional.txt`.

Interactive IMC:

```bash
imc -load cov_work/merged &
```

## What to look at first when elaboration fails

- `` `include `` of the UVM classes needs `+incdir+../uvm`, which is already in `filelist_uvm.f`. Run `xrun` from `sim/` so the relative paths resolve.
- `fswwdt_sva` must be on the file list whenever `FSWWDT_ASSERT` is defined, because `fswwdt_core` instantiates it.
- A license failure is `-licqueue` waiting, or a missing `XCELIUM` / `UVM` feature. That is a site setup issue, not an RTL error.
