package main

import (
  "fmt"
)

func tokens(s []byte, isSpace func(byte) bool) []string {
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

	ids := filter(5000, check, n+1, func (i int) int { return i })
	count := len(ids) / 2

	result := make([]string, count)
	parallelRange(5000, 0, count, func (lo, hi int) {
		for i := lo; i < hi; i++ {
			start := ids[2*i]
			stop := ids[2*i+1]

			result[i] = string(s[start:stop])

			// str := make([]byte, stop-start)
			// for j := 0; j < stop-start; j++ {
			// 	str[j] = s[start+j]
			// }
			// result[i] = string(str)
		}
	})

	return result
}

func isSpace(b byte) bool {
	return (b == 32) ||  // space
	       (b == 10) ||  // newline
				 (b == 13) ||  // carriage return
				 (b == 9)      // tab
}

func main() {
	path := parseString("infile", "file.txt")
  fmt.Printf("infile %s\n", path)

	var contents []byte
	tm := getTime(func() { contents = readFileContents(path) })
	fmt.Printf("read file in %.3fs\n", tm);

  var result []string
	benchmarkRun("tokens", func(){ result = tokens(contents, isSpace) })

  fmt.Printf("number of tokens %d\n", len(result))
	for i := 0; i < 10; i++ {
		// result[i].Print()
    fmt.Printf("%s ", result[i])
  }
  fmt.Printf("...\n")
}
