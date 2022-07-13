package main

import (
	"time"
	"fmt"
	"runtime"
)

func getTime(f func()) float64 {
	t0 := time.Now ()
	f()
	return time.Since(t0).Seconds()
}

func benchmarkRun(msg string, f func()) {
  repeat := max[int](1, parseInt("repeat", 1))
	warmup := max[float64](0.0, parseFloat64("warmup", 0.0))
	procs := max[int](1, parseInt("procs", 1))
  runtime.GOMAXPROCS(procs)

	if warmup > 0.001 {
    fmt.Printf("============ WARMUP ============\n")
    tStart := time.Now()
    for time.Since(tStart).Seconds() < warmup {
      tm := getTime(f)
      fmt.Printf("warmup_run %.3fs\n", tm);
    }
    fmt.Printf("========== END WARMUP ==========\n");
  }

  tms := make([]float64, repeat)

  fmt.Printf(msg + "\n")

  for i := 0; i < repeat; i++ {
    tm := getTime(f)
    fmt.Printf("time %.3fs\n", tm);
    tms[i] = tm;
  }

  sum := 0.0
	for i := 0; i < repeat; i++ {
		sum += tms[i]
	}
	fmt.Printf("\naverage %.3fs\n", sum / float64(repeat))
}
