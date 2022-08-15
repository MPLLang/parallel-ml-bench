package main

import (
	"time"
	"fmt"
	"runtime"
	"runtime/debug"
)

func getTime(f func()) float64 {
	t0 := time.Now ()
	f()
	return time.Since(t0).Seconds()
}

func makeStats() debug.GCStats {
	return debug.GCStats{
		// LastGC: time.UnixMilli(0),
		NumGC: 0,
    PauseTotal: time.UnixMilli(0).Sub(time.UnixMilli(0)),
		Pause: make([]time.Duration, 5),
	}
}

func benchmarkRun(msg string, f func()) {
  repeat := max[int](1, parseInt("repeat", 1))
	warmup := max[float64](0.0, parseFloat64("warmup", 0.0))
	procs := max[int](1, parseInt("procs", 1))
	gcpct := parseInt("gcpct", 100)
  runtime.GOMAXPROCS(procs)
	old_gcpct := debug.SetGCPercent(gcpct)
	if (old_gcpct != gcpct) {
		fmt.Printf("gcpct %d (old value %d)\n", gcpct, old_gcpct)
	}

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

	stats0 := makeStats()
	debug.ReadGCStats(&stats0)

  fmt.Printf(msg + "\n")

  for i := 0; i < repeat; i++ {
    tm := getTime(f)
    fmt.Printf("time %.3fs\n", tm);
    tms[i] = tm;
  }

	stats1 := makeStats()
	debug.ReadGCStats(&stats1)

  sum := 0.0
	for i := 0; i < repeat; i++ {
		sum += tms[i]
	}
	fmt.Printf("\naverage %.3fs\n", sum / float64(repeat))

	fmt.Printf("average-num-gcs %.1f\n", float64(stats1.NumGC - stats0.NumGC) / float64(repeat));
	fmt.Printf("average-gc-pause %.5f\n", (stats1.PauseTotal.Seconds() - stats0.PauseTotal.Seconds()) / float64(repeat));
}
