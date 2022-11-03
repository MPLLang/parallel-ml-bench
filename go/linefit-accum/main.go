package main

import (
  "fmt"
)

type P struct {
	x float64
	y float64
}

func sumPair(a, b P) P {
	return P { x: a.x + b.x, y: a.y + b.y }
}

func square(x float64) float64 {
	return x * x
}

func linefit (input []P) P {

	z := P { x: 0.0, y: 0.0 }

	sum := func (f func (P) P) P {
		return commutativeAccum(100000, sumPair, z, 0, len(input), func (i int) P {
			return f(input[i])
		})
	}

	r := sum(func (p P) P { return p })
	xsum, ysum := r.x, r.y
  n := float64(len(input))
	xa, ya := xsum / n, ysum / n

  r = sum(func (p P) P { return P { x: square(p.x - xa), y: (p.x - xa) * p.y } })
	Stt, bb := r.x, r.y

	b := bb / Stt
	a := ya - xa * b

	return P { x: a, y: b }
}

func gen(i int) float64 {
	return float64(int(hash64(uint64(i)) % uint64(1000)) - 500) / float64(500.0)
}

func main() {
	n := parseInt("n", 1000 * 1000 * 100)
  fmt.Printf("n %d\n", n)

	input := make([]P, n)
	parallelRange(5000, 0, n, func (lo, hi int) {
		for i := lo; i < hi; i++ {
			input[i] = P{x: float64(i), y: float64(i)}
		}
	})

  var result P
	benchmarkRun("linefit", func(){ result = linefit(input) })

  fmt.Print("a ", result.x, "\n")
	fmt.Print("b ", result.y, "\n")
}
