package main

import (
  // "os"
  "fmt"
  // "time"
  "github.com/intel/forGoParallel/psort"
	"github.com/intel/forGoParallel/parallel"
)

func doSort(input []int64) []int64 {
	copied := make([]int64, len(input))

	f := func(low, high int) {
		for i := low; i < high; i++ {
			copied[i] = input[i]
		}
	}
	parallel.Range(0, len(input), f)
	psort.Sort(Int64Slice(copied))
	return copied
}

func main() {
  n := parseInt("n", 1000000)
  fmt.Printf("n %d\n", n)

  xs := make([]int64, n)
	parallel.Range(0, n, func(low, high int) {
		for i := low; i < high; i++ {
			xs[i] = int64(hash64(uint64(i)) % uint64(n))
		}
	})

	var result []int64
	f := func(){ result = doSort(xs) }
	benchmarkRun("sort", f)

  for i := 0; i < 10; i++ {
    fmt.Printf("%d ", result[i])
  }
  fmt.Printf("...\n")
}
