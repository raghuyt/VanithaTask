# Merge per-test Xcelium databases after sim/run_regress.sh -cov
merge cov_work -out cov_work/merged -overwrite
load cov_work/merged
report -metrics overall -out ../docs/cov_summary.txt
report -detail -metrics functional -out ../docs/cov_functional.txt
