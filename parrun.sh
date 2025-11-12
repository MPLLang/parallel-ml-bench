#!/usr/bin/env bash

set -e

if [ $# -eq 0 ];
then echo "USAGE
$0 RESULT_NAME" >&2;
     exit 1
fi


ROOT=$(git rev-parse --show-toplevel)

mkdir -p $ROOT/results
RESULTS=$ROOT/results/$1.json

rm -f $ROOT/mpl/bin/*.bin
rm -f $ROOT/cpp/bin/*.bin

$ROOT/filter-exps.py $ROOT/spork-exp-hb.json $ROOT/filtered-exp-hb.json

$ROOT/scripts/gencmds $ROOT/filtered-exp-hb.json | tee /dev/stderr | taskset -c 0-79 $ROOT/scripts/parruncmds.py --compile --output $RESULTS

echo "[INFO] wrote results to $RESULTS"

$ROOT/report-shootout.py
