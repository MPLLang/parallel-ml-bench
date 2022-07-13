package main

import (
  "sort"
  // "fmt"
)
func (s ElementSlice) Less (i, j int) bool {
	return s[i] < s[j]
  // return (&s[i]).Less(&s[j])
}

func (s ElementSlice) Len() int {
  return len(s)
}

func (s ElementSlice) Swap(i, j int) {
  s[i], s[j] = s[j], s[i]
}

// A function suitable to be used as a goroutine
func sequential_sort(seq ElementSlice, done chan bool) {
  sort.Sort(seq)
  done <- true
}

func sequential_sort_copy(input, output ElementSlice) {
  for i:=0;i<len(input);i++ {
    output[i] = input[i]
  }
  sort.Sort(output)
}

/*
func sequential_sort_by_index(seq PElementSlice, done chan bool) {
  // The list to be sorted
  n := int32(len(seq))
  idx := make([]int32, n)
  for i:=int32(0);i<n;i++ {
    idx[i] = i
  }

  // for i:=int32(0);i<n;i++ {
  //   fmt.Printf("%v: ", i)
  //   seq[i].Print()
  // }

  // Sort indices by their elements
  sort.Slice(idx, func(i, j int) bool { return (&seq[idx[i]]).Less(&seq[idx[j]]) })
  // sort.Slice(idx, func(i, j int) bool { return seq[i].x > seq[j].x })
  // sort.Slice(idx, func(i, j int) bool { return i > j })

  // fmt.Println("Sorted")

  // for _,x := range(idx) {
  //   fmt.Printf("%v ", x)
  //   seq[x].Print()
  // }
  // fmt.Println()

  // First attempt: naive

  // tmp := make(ElementSlice, n)

  // for i:=int32(0);i<n;i++ {
  //   tmp[i] = seq[idx[i]]
  // }

  // for i:=int32(0);i<n;i++ {
  //   seq[i] = tmp[i]
  // }

  // Second pass: unravel the permutation

  for i:=int32(0);i<n;i++ {
    if idx[i] < n {
      tmp := seq[i] // hold in our hand the current element

      j := i
      for idx[j] != i {
        seq[j] = seq[idx[j]]
        next := idx[j]
        idx[j] = n
        j = next
      }
      seq[j] = tmp
      idx[j] = n
    }
  }

  done <-true
}
*/
