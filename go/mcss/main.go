package main

import (
  "fmt"
)

type M struct {
	l float64
	r float64
  b float64
	t float64
}

func combine(x, y M) M {
	result := M {
		l: max(x.l, x.t + y.l),
    r: max(y.r, x.r + y.t),
    b: max(x.r + y.l, max(x.b, y.b)),
    t: x.t + y.t,
	}

	return result
}

func mcss (input []float64) float64 {

	z := M { l: 0.0, r: 0.0, b: 0.0, t: 0.0 }

	r := reduce(5000, combine, z, 0, len(input), func (i int) M {
		v := input[i]
		vp := max(v, 0.0)
		return M {
			l: vp,
			r: vp,
			b: vp,
			t: v,
		}
	})

  return r.b
}


func gen(i int) float64 {
	return float64(int(hash64(uint64(i)) % uint64(1000)) - 500) / float64(500.0)
}

func main() {
	n := parseInt("n", 1000 * 1000 * 100)
  fmt.Printf("n %d\n", n)

	input := make([]float64, n)
	parallelRange(5000, 0, n, func (lo, hi int) {
		for i := lo; i < hi; i++ {
			input[i] = gen(i)
		}
	})

  var result float64
	benchmarkRun("mcss", func(){ result = mcss(input) })

  fmt.Print("result ", result, "\n")

  fmt.Print("input ")
	for i := 0; i < min(n, 10); i++ {
		fmt.Printf("%.3f ", input[i])
	}
	fmt.Print("...\n")
}
