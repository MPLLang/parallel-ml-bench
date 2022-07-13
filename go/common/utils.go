package main

import (
  "os"
  "fmt"
  "strconv"
  "golang.org/x/exp/constraints"
)

func min[T constraints.Ordered](x,y T) T {
  if x < y {
    return x
  }
  return y
}

func max[T constraints.Ordered](x,y T) T {
  if x > y {
    return x
  }
  return y
}


func string_to_int(s string) int {
  x, err := strconv.Atoi(s)
  if err != nil {
      fmt.Println(err)
      os.Exit(1)
  }
  return x
}

func string_to_float64(s string) float64 {
  x, err := strconv.ParseFloat(s, 64)
  if err != nil {
      fmt.Println(err)
      os.Exit(1)
  }
  return x
}

func hash64(u uint64) uint64 {
  v := u * 3935559000370003845 + 2691343689449507681
  v ^= v >> 21
  v ^= v << 37
  v ^= v >>  4
  v *= 4768777513237032717
  v ^= v << 20
  v ^= v >> 41
  v ^= v <<  5
  return v
}
