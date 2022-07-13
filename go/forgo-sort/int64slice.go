package main

import (
	"sort"
)

// Adapted from https://github.com/intel/forGoParallel/blob/main/psort/sort.go

type Int64Slice []int64

func (s Int64Slice) SequentialSort(i, j int) {
	sort.Sort(s[i:j])
}

func (s Int64Slice) Len() int {
	return len(s)
}

func (s Int64Slice) Less(i, j int) bool {
	return s[i] < s[j]
}

func (s Int64Slice) Swap(i, j int) {
	s[i], s[j] = s[j], s[i]
}

// NewTemp implements the method of the StableSorter interface.
// func (s Int64Slice) NewTemp() StableSorter {
// 	return Int64Slice(make([]int64, len(s)))
// }

// // Assign implements the method of the StableSorter interface.
// func (s Int64Slice) Assign(source StableSorter) func(i, j, len int) {
// 	dst, src := s, source.(Int64Slice)
// 	return func(i, j, len int) {
// 		copy(dst[i:i+len], src[j:j+len])
// 	}
// }

// // Float64sAreSorted determines in parallel whether a slice of float64s is
// // already sorted in increasing order. It attempts to terminate early when the
// // return value is false.
// func Float64sAreSorted(a []float64) bool {
// 	return IsSorted(Int64Slice(a))
// }
