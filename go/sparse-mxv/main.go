package main

import (
  "fmt"
)

type ix struct {
	i int
	x float64
}

func sparseMxV(M [][]ix, V []float64) []float64 {
	result := tabulate(100, len(M), func(i int) float64 {
		row := M[i]
		return reduce(
			5000,
		  func(a,b float64) float64 { return a+b },
			float64(0.0),
			0,
			len(row),
			func(j int) float64 {
				elem := row[j]
				return V[elem.i] * elem.x
			})
	})

	return result
}

func gen(rowLen, numRows, i, j int) ix {
	return ix{
		i: int(unsignedMod(int64(hash64(uint64(i*rowLen + j))), int64(numRows))),
		x: 1.0,
	}
}

func main() {
	n := parseInt("n", 1000 * 1000 * 100)
  fmt.Printf("n %d\n", n)

	rowLen := 100
	numRows := n / rowLen
	vec := tabulate(5000, numRows, func (i int) float64 { return float64(1.0) })
  mat := tabulate(100, numRows, func (i int) []ix {
		return tabulate(5000, rowLen, func (j int) ix {
			return gen(rowLen, numRows, i, j) })
	})

  var result []float64
	benchmarkRun("sparse-mxv", func(){ result = sparseMxV(mat, vec) })

  fmt.Print("result ")
	for i := 0; i < min(numRows, 10); i++ {
		fmt.Printf("%.1f ", result[i])
	}
	fmt.Print("...\n")
}
