package main

import (
  "fmt"
	// "math"
	"github.com/intel/forGoParallel/parallel"
)

func add64(a, b int64) int64 {
	return a+b
}

func plusScan(input []int64) []int64 {
	return scan(5000, add64, 0, input)
}

func main() {
	n := parseInt("n", 10000000)
  fmt.Printf("n %d\n", n)

	input := make([]int64, n)
	parallel.Range(0, n, func(low, high int) {
		for i := low; i < high; i++ {
			input[i] = 1
		}
	})

	var result []int64
	benchmarkRun("test-scan", func(){ result = plusScan(input) })

	for i := 0; i < 10; i++ {
		// result[i].Print()
    fmt.Printf("%d ", result[i])
  }
  fmt.Printf("...\n")
}
