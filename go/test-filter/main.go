package main

import (
  "fmt"
	// "math"
	"github.com/intel/forGoParallel/parallel"
)

func doFilter(input []int64) []int64 {
	return filter(
		5000,
		func(i int) bool { return input[i] % 3 == 0 },
		len(input),
		func(i int) int64 { return input[i] })
}

func main() {
	n := parseInt("n", 10000000)
  fmt.Printf("n %d\n", n)

	input := make([]int64, n)
	parallel.Range(0, n, func(low, high int) {
		for i := low; i < high; i++ {
			input[i] = int64(hash64(uint64(i)) % uint64(100))
		}
	})

	var result []int64
	benchmarkRun("test-filter", func(){ result = doFilter(input) })

	for i := 0; i < 10; i++ {
		// result[i].Print()
    fmt.Printf("%d ", result[i])
  }
  fmt.Printf("...\n")
}
