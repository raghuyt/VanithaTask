# FSWWDT simulation makefile. Run from sim/ on a Cadence Linux host.
# Xcelium provides UVM. If your site needs an explicit install, add -uvmhome <path>.

XRUN    ?= xrun
TEST    ?= fswwdt_basic_test
PERIOD  ?= 100

COMMON = -64bit -sv -timescale 1ns/1ps -access +rwc -licqueue \
	-uvm +define+FSWWDT_ASSERT +UVM_NO_RELNOTES \
	-f filelist_uvm.f

.PHONY: help smoke sim waves cov regress merge clean

help:
	@echo "make smoke                  RTL smoke (no UVM)"
	@echo "make sim TEST=<uvm test>    one test, default $(TEST)"
	@echo "make waves TEST=<uvm test>  one test + VCD (plusarg DUMP)"
	@echo "make cov TEST=<uvm test>    one test with coverage"
	@echo "make regress                all tests"
	@echo "make regress PERIOD=40      repeat freq sensitivity"
	@echo "make merge                  imc merge after a coverage regress"

smoke:
	mkdir -p logs
	$(XRUN) -64bit -sv -timescale 1ns/1ps -access +rwc -licqueue \
		+define+FSWWDT_ASSERT -f filelist_smoke.f -top tb_rtl_smoke \
		-l logs/smoke.log

sim:
	mkdir -p logs
	$(XRUN) $(COMMON) +UVM_TESTNAME=$(TEST) +WDT_CLK_NS=$(PERIOD) \
		-l logs/$(TEST).log

waves:
	mkdir -p logs
	$(XRUN) $(COMMON) +UVM_TESTNAME=$(TEST) +WDT_CLK_NS=$(PERIOD) +DUMP \
		-l logs/$(TEST)_waves.log

cov:
	mkdir -p logs
	$(XRUN) $(COMMON) -covfile cov.ccf -coverage all -covoverwrite \
		-covtest $(TEST) +UVM_TESTNAME=$(TEST) +WDT_CLK_NS=$(PERIOD) \
		-l logs/$(TEST)_cov.log

regress:
	mkdir -p logs
	@fail=0; \
	for t in fswwdt_reg_test fswwdt_basic_test fswwdt_window_test \
		fswwdt_timeout_test fswwdt_early_test fswwdt_late_test \
		fswwdt_irq_test fswwdt_reset_test fswwdt_err_inject_test \
		fswwdt_por_test fswwdt_warm_reset_test fswwdt_async_reset_test \
		fswwdt_sync_reset_test fswwdt_clk_stop_test fswwdt_freq_test \
		fswwdt_reset_during_run_test fswwdt_reset_during_to_test \
		fswwdt_cov_fill_test fswwdt_rand_test; do \
		echo "---- $$t ----"; \
		$(XRUN) $(COMMON) -covfile cov.ccf -coverage all -covoverwrite \
			-covtest $$t +UVM_TESTNAME=$$t +WDT_CLK_NS=$(PERIOD) \
			-l logs/$$t.log || fail=1; \
		if grep -E -q "TEST FAILED|FSWWDT:|\\*E," logs/$$t.log; then \
			echo "FAIL $$t"; fail=1; \
		elif grep -q "TEST PASSED" logs/$$t.log; then \
			echo "PASS $$t"; \
		else \
			echo "FAIL $$t (no pass banner)"; fail=1; \
		fi; \
	done; \
	exit $$fail

merge:
	imc -exec cov_merge.tcl

clean:
	rm -rf logs xcelium.d cov_work waves.shm INCA_libs *.vcd *.log *.history *.key
