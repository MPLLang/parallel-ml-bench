package main

import (
  "fmt"
	"testing"
	"runtime"
)

func TestTokens(t *testing.T) {
  path := "../../inputs/words256.txt"
	contents := readFileContents(path)

  runtime.GOMAXPROCS(72)

  var result []string
	for i := 0; i < 20; i++ {
		result = tokens(contents, isSpace)
	}

  fmt.Printf("number of tokens %d\n", len(result))
}
