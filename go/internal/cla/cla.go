package cla

import (
  "os"
	"parallel-ml-bench-go/internal/utils"
  // "fmt"
)

func parseInt(key string, d int) int {
  for i := 1; i < len(os.Args); i++ {
    if os.Args[i] == ("-" + key) {
      return utils.string_to_int(os.Args[i+1])
    }
  }
  return d
}
