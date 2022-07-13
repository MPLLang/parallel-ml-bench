package main

import (
  "fmt"
	"math"
)

func assert(id int, x bool) {
  if x == false {
    fmt.Printf("Assertion %v failed!\n", id)
  }
}

// func min(x,y int) int {
//   if x < y {
//     return x
//   }
//   return y
// }

func block(seq ElementSlice, i, n_blocks int) (ElementSlice, int) {
  n := len(seq)
  stride := n / n_blocks
  start := i * stride
  end := start + stride
  if i+1 == n_blocks {
    end = n
  }

  return seq[start:end], start
}

// func string_to_int(s string) int {
//   x, err := strconv.Atoi(s)
//   if err != nil {
//       fmt.Println(err)
//       os.Exit(1)
//   }
//   return x
// }

// func hash64(u uint64) uint64 {
//   v := u * 3935559000370003845 + 2691343689449507681
//   v ^= v >> 21
//   v ^= v << 37
//   v ^= v >>  4
//   v *= 4768777513237032717
//   v ^= v << 20
//   v ^= v >> 41
//   v ^= v <<  5
//   return v
// }

func hash32(x int32) int32 {
  return int32(hash64(uint64(x)) % math.MaxInt32)
}

func barrier(done chan bool, n int) {
  for i:=0;i<n;i++ { <-done }
}
