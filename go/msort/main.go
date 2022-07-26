package main

import (
  "fmt"
	"sort"
)

type ElementSlice []int64

func (s ElementSlice) Less (i, j int) bool {
	return s[i] < s[j]
}

func (s ElementSlice) Len() int {
  return len(s)
}

func (s ElementSlice) Swap(i, j int) {
  s[i], s[j] = s[j], s[i]
}

func writeSort(s, t ElementSlice) {
	n := len(s)
	if n <= 1000 {
		copy(t, s)
		sort.Sort(t)
		return
	}

	half := n/2
	sl := s[:half]
	sr := s[half:]
	tl := t[:half]
	tr := t[half:]
	pardo(func(){ writeSortInPlace(sl, tl) },
	      func(){ writeSortInPlace(sr, tr) })
	writeMerge(sl, sr, t)
}

func writeSortInPlace(s, t ElementSlice) {
	n := len(s)
	if n <= 1000 {
		sort.Sort(s)
		return
	}

	half := n/2
	sl := s[:half]
	sr := s[half:]
	tl := t[:half]
	tr := t[half:]
	pardo(func(){ writeSort(sl, tl) },
	      func(){ writeSort(sr, tr) })
	writeMerge(tl, tr, s)
}

func sortInPlace(s ElementSlice) {
	t := make(ElementSlice, len(s))
	writeSortInPlace(s, t)
}

func pureSort(s ElementSlice) ElementSlice {
	t := make(ElementSlice, len(s))
	parallelRange(5000, 0, len(s), func (lo, hi int) {
		for i := lo; i < hi; i++ {
			t[i] = s[i]
		}
	})
	sortInPlace(t)
	return t
}


func main() {
	n := parseInt("n", 1000 * 1000 * 100)
  fmt.Printf("n %d\n", n)

	input := make([]int64, n)
	parallelRange(5000, 0, n, func (lo, hi int) {
		for i := lo; i < hi; i++ {
			h := int64(hash64(uint64(i)) % uint64(n))
			input[i] = h
		}
	})

  var result []int64
	benchmarkRun("msort", func(){ result = pureSort(input) })

  fmt.Print("input ")
	for i := 0; i < min(n, 10); i++ {
		fmt.Printf("%d ", input[i])
	}
	fmt.Print("...\n")

  fmt.Print("result ")
	for i := 0; i < min(n, 10); i++ {
		fmt.Printf("%d ", result[i])
	}
	fmt.Print("...\n")
}
