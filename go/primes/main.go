package main

import (
  "fmt"
	"math"
	"github.com/intel/forGoParallel/parallel"
)


func primesUpto(n int) []int64 {
	if n < 2 {
		return make([]int64, 0)
	}

	sqrtPrimes := primesUpto(int(math.Floor(math.Sqrt(float64(n)))))
  // fmt.Printf("primesUpto(%d): len(sqrtPrimes) = %d\n", n, len(sqrtPrimes))

	flags := make([]bool, n+1)
	parallel.Range(0, n+1, func(low, high int) {
		for i := low; i < high; i++ {
	  	flags[i] = true
		}
	})

	parallel.Range(0, len(sqrtPrimes), func(iLo, iHi int) {
		for i := iLo; i < iHi; i++ {
			p := int(sqrtPrimes[i])
			numMultiples := n / p - 1
			// fmt.Printf("num multiples of %d: %d\n", p, numMultiples)
			parallel.Range(0, numMultiples, func(jLo, jHi int) {
				for j := jLo; j < jHi; j++ {
					// fmt.Printf("multiple of %d: %d\n", p, (j+2)*p)
					flags[(j+2)*p] = false
				}
			})
		}
	})

	result := filterRange(5000,
	  func(i int) bool { return flags[i] },
		2,
		n+1,
		func(i int) int64 { return int64(i) })

  // fmt.Printf("primesUpto(%d): len(result) = %d\n", n, len(result))

  return result
}


func main() {
	n := parseInt("n", 100000000)
  fmt.Printf("n %d\n", n)

	var result []int64
	benchmarkRun("primes", func(){ result = primesUpto(n) })

  fmt.Printf("number of primes %d\n", len(result))
	for i := 0; i < 10; i++ {
		// result[i].Print()
    fmt.Printf("%d ", result[i])
  }
  fmt.Printf("...\n")
}
