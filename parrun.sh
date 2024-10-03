#!/usr/bin/env bash

set -e

if [ $# -eq 0 ];
then echo "USAGE
$0 RESULT_NAME" >&2;
     exit 1
fi


ROOT=$(git rev-parse --show-toplevel)
GEN=$ROOT/scripts/gencmds
RUN=$ROOT/scripts/parruncmds.py

mkdir -p $ROOT/results
RESULTS=$ROOT/results/$1.json

rm -f $ROOT/mpl/bin/*.bin

$ROOT/filter-exps.py $ROOT/spork-exp-hb.json $ROOT/filtered-exp-hb.json

$GEN $ROOT/filtered-exp-hb.json | taskset -c 0-71 $RUN --compile --output $RESULTS

echo "[INFO] wrote results to $RESULTS"

$ROOT/report-shootout.py
