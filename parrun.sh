#!/usr/bin/env bash

set -e

ROOT=$(git rev-parse --show-toplevel)
GEN=$ROOT/scripts/gencmds
RUN=$ROOT/scripts/parruncmds.py

NOW=$(date '+%y%m%d-%H%M%S')
# NOW="230217-050444"
mkdir -p $ROOT/results
RESULTS=$ROOT/results/$NOW.json

rm -f $ROOT/mpl/bin/*.bin

$ROOT/filter-exps.py $ROOT/spork-exp-hb.json $ROOT/filtered-exp-hb.json $ROOT/exps_to_run.txt

$GEN $@ $ROOT/filtered-exp-hb.json | taskset -c 0-72 $RUN --compile --output $RESULTS

echo "[INFO] wrote results to $RESULTS"

$ROOT/results/report-shootout.py
