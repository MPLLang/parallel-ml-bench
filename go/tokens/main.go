package main

import (
  "fmt"
)

func main() {
	path := parseString("infile", "file.txt")
  fmt.Printf("infile %s\n", path)

	var contents []byte
	tm := getTime(func() { contents = readFileContents(path) })
	fmt.Printf("read file in %.3fs\n", tm);

  var result []ByteSlice
	benchmarkRun("tokens", func(){ result = tokens(contents, isSpace) })

  fmt.Printf("number of tokens %d\n", len(result))
	for i := 0; i < 10; i++ {
		// result[i].Print()
		x := result[i]
    fmt.Printf("%s ", string(x.data[x.start : (x.start+x.length)]))
  }
  fmt.Printf("...\n")
}
