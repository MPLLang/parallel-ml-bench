package main

import (
  // "os"
  "fmt"
  // "time"
  "runtime"
  "github.com/intel/forGoParallel/psort"
)

func main() {
  procs := parseInt("procs", 1)
  n := parseInt("n", 1000000)
  runtime.GOMAXPROCS(procs)
  fmt.Printf("procs %d\nn %d\n", procs, n)

  xs := make([]int, n)
  for i := 0; i < n; i++ {
    xs[i] = (int)(hash64(uint64(i)) % uint64(n))
  }

  psort.Sort(psort.IntSlice(xs))

  for i := 0; i < 10; i++ {
    fmt.Printf("%d ", xs[i])
  }
  fmt.Printf("...\n")
}
