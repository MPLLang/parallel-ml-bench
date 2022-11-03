package main

import (
  "fmt"
)

type BS struct {
	lineBreaks int
	wordStarts int
}

func sumBS(a, b BS) BS {
	return BS {
		lineBreaks: a.lineBreaks + b.lineBreaks,
		wordStarts: a.wordStarts + b.wordStarts,
	}
}

func wc(contents []byte) (int, int, int) {
	f := func (i int) BS {
		var wordStarts, lineBreaks int
		if ((i == 0) || isSpace(contents[i-1])) && !isSpace(contents[i]) {
			wordStarts = 1
		} else {
			wordStarts = 0
		}

		if contents[i] == 10 /* ASCII newline */ {
			lineBreaks = 1
	  } else {
			lineBreaks = 0
		}

		return BS { lineBreaks: lineBreaks, wordStarts: wordStarts }
	}

  z := BS { lineBreaks: 0, wordStarts: 0 }
  bs := commutativeAccum(100000, sumBS, z, 0, len(contents), f)

	return bs.lineBreaks, bs.wordStarts, len(contents)
}

func main() {
	path := parseString("infile", "file.txt")
  fmt.Printf("infile %s\n", path)

	var contents []byte
	tm := getTime(func() { contents = readFileContents(path) })
	fmt.Printf("read file in %.3fs\n", tm);

  var lines, words, bytes int
	benchmarkRun("wc", func() {
		lines, words, bytes = wc(contents)
	})

  fmt.Printf("lines %d\nwords %d\nbytes %d\n", lines, words, bytes)
}
