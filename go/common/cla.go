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
