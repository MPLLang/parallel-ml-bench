package main

import (
  "fmt"
	"os"
	"time"
)

// func check(s []byte, i int) bool {
// 	n := len(s)

// 	if i == n {
// 		return !(isSpace(s[n-1]))
// 	} else if i == 0 {
// 		return !(isSpace(s[0]))
// 	}

// 	i1 := isSpace(s[i])
// 	i2 := isSpace(s[i-1])

// 	return (i1 && !i2) || (i2 && !i1)
// }

func tokensCheat(s []byte, isSpace func(byte) bool, result []string, tmpBlocks []int, tmpIds []int) {
	tm := time.Now()

	// =========================================================================

	n := len(s)
	check := func(i int) bool {
		if i == n {
			return !(isSpace(s[n-1]))
		} else if i == 0 {
			return !(isSpace(s[0]))
		}

		i1 := isSpace(s[i])
		i2 := isSpace(s[i-1])

		return (i1 && !i2) || (i2 && !i1)
	}

	nn := 1 + len(s)

  grain := 5000
	blockSize := grain
	numBlocks := 1 + (nn-1) / blockSize
	// blockCounts := make([]int, numBlocks)
	blockCounts := tmpBlocks //arrayAlloc[int](numBlocks)
	tm = tickSince(tm, "tokens:filter:alloc")
	parallelRange(1, 0, numBlocks, func(bLo, bHi int) {
		for b := bLo; b < bHi; b++ {
			start := b*blockSize
			stop := min(nn, (b+1)*blockSize)
			count := 0
			for i := start; i < stop; i++ {
				if check(i) {
					count++
				}
			}
			blockCounts[b] = count
		}
	})

	tm = tickSince(tm, "tokens:filter:block-counts")

	offsets := scan(grain, func(a, b int) int { return a+b }, 0, blockCounts)
	// total := offsets[numBlocks]
	tm = tickSince(tm, "tokens:filter:scan-offsets")

	ids := tmpIds // arrayAlloc[int](total)
	tm = tickSince(tm, "tokens:filter:alloc-output")
	parallelRange(1, 0, numBlocks, func(bLo, bHi int) {
		for b := bLo; b < bHi; b++ {
			start := b*blockSize
			stop := min(nn, (b+1)*blockSize)
			j := offsets[b]
			for i := start; i < stop; i++ {
				if check(i) {
					ids[j] = i
					j++
				}
			}
		}
	})
	tm = tickSince(tm, "tokens:filter:fill-output")

	// =========================================================================

	count := len(ids) / 2

  // result := arrayAlloc[string](count)

	tm = tickSince(tm, "tokens:alloc-output")

	parallelRange(5000, 0, count, func (lo, hi int) {
		for i := lo; i < hi; i++ {
			start := ids[2*i]
			stop := ids[2*i+1]

			// result[i] = string(s[start:stop])
			for j := 0; j < stop-start; j++ {
				if (s[start+j] != result[i][j]) {
					fmt.Println("Error at %d, %d", i, j)
					os.Exit(1)
				}
			}
		}
	})

	tm = tickSince(tm, "tokens:fill-output")

	// return result
}

func main() {
	path := parseString("infile", "file.txt")
  fmt.Printf("infile %s\n", path)

	var contents []byte
	tm := getTime(func() { contents = readFileContents(path) })
	fmt.Printf("read file in %.3fs\n", tm)

	result := tokens(contents, isSpace)
	blockSize := 5000
	numBlocks := 1 + (len(contents) / blockSize)
	tmpBlocks := arrayAlloc[int](numBlocks)
	tmpIds := arrayAlloc[int](2 * len(result))

	benchmarkRun("tokens", func(){
		tokensCheat(contents, isSpace, result, tmpBlocks, tmpIds)
  })

  fmt.Printf("number of tokens %d\n", len(result))
	for i := 0; i < 10; i++ {
		// result[i].Print()
    fmt.Printf("%s ", result[i])
  }
  fmt.Printf("...\n")
}
