package main

import (
  "fmt"
	"sort"
)

type ElementSlice []string

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
	path := parseString("infile", "file.txt")
  fmt.Printf("infile %s\n", path)

	var contents []byte
	tm := getTime(func() { contents = readFileContents(path) })
	fmt.Printf("read file in %.3fs\n", tm);

  var input []string
	tm = getTime(func() { input = tokens(contents, isSpace) })
	fmt.Printf("tokenized in %.3fs\n", tm);

  var result []string
	benchmarkRun("msort", func(){ result = pureSort(input) })

  fmt.Print("input ")
	for i := 0; i < min(len(input), 10); i++ {
		fmt.Printf("%s ", input[i])
	}
	fmt.Print("...\n")

  fmt.Print("result ")
	for i := 0; i < min(len(result), 10); i++ {
		fmt.Printf("%s ", result[i])
	}
	fmt.Print("...\n")
}
