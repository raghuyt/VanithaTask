#!/usr/bin/env bash
# Regression runner. Prefer `make regress` from sim/. This script is the
# same loop for hosts that invoke bash directly.
set -u
cd "$(dirname "$0")"
period="${WDT_CLK_NS:-100}"
fail=0
mkdir -p logs
tests=(
  fswwdt_reg_test
  fswwdt_basic_test
  fswwdt_window_test
  fswwdt_timeout_test
  fswwdt_early_test
  fswwdt_late_test
  fswwdt_irq_test
  fswwdt_reset_test
  fswwdt_err_inject_test
  fswwdt_por_test
  fswwdt_warm_reset_test
  fswwdt_async_reset_test
  fswwdt_sync_reset_test
  fswwdt_clk_stop_test
  fswwdt_freq_test
  fswwdt_reset_during_run_test
  fswwdt_reset_during_to_test
  fswwdt_cov_fill_test
  fswwdt_rand_test
)
for t in "${tests[@]}"; do
  echo "---- ${t} ----"
  xrun -64bit -sv -timescale 1ns/1ps -access +rwc -licqueue \
    -uvm +define+FSWWDT_ASSERT +UVM_NO_RELNOTES \
    -f filelist_uvm.f \
    -covfile cov.ccf -coverage all -covoverwrite -covtest "${t}" \
    +UVM_TESTNAME="${t}" +WDT_CLK_NS="${period}" \
    -l "logs/${t}.log"
  status=$?
  if [[ ${status} -ne 0 ]]; then
    echo "FAIL ${t} (xrun ${status})"
    fail=1
  elif grep -E -q "TEST FAILED|FSWWDT:|\*E," "logs/${t}.log"; then
    echo "FAIL ${t}"
    fail=1
  elif grep -q "TEST PASSED" "logs/${t}.log"; then
    echo "PASS ${t}"
  else
    echo "FAIL ${t} (no pass banner)"
    fail=1
  fi
done
exit ${fail}
