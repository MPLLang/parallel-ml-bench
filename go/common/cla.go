package main

import (
  "os"
  // "fmt"
)

func parseInt(key string, d int) int {
  for i := 1; i < len(os.Args); i++ {
    if os.Args[i] == ("-" + key) {
      return string_to_int(os.Args[i+1])
    }
  }
  return d
}

func parseString(key string, d string) string {
  for i := 1; i < len(os.Args); i++ {
    if os.Args[i] == ("-" + key) {
      return os.Args[i+1]
    }
  }
  return d
}

func parseFloat64(key string, d float64) float64 {
  for i := 1; i < len(os.Args); i++ {
    if os.Args[i] == ("-" + key) {
      return string_to_float64(os.Args[i+1])
    }
  }
  return d
}
