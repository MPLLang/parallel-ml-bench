package main

import (
  "os"
	"io/ioutil"
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


func readFileContents(path string) []byte {
	file, err := os.Open(path)
	if err != nil {
		fmt.Println(err)
    os.Exit(1)
	}
	defer func() {
		err = file.Close()
		if err != nil {
			fmt.Println(err)
	    os.Exit(1)
		}
	}()

	contents, err := ioutil.ReadAll(file)
	return contents
}


// func pardo(f, g func()) {
// 	var wg sync.WaitGroup
// 	wg.Add(1)
// 	go func() { g(); wg.Done()} ()
// 	f()
// 	wg.Wait()
// }

func pardo(f, g func()) {
	done := make(chan bool)
	go func() { g(); done <- true} ()
	f()
	<-done
}

func parallelRange(grain, start, stop int, f func(int, int)) {
	if stop-start <= grain {
		f(start, stop)
		return
	}

	mid := start + ((stop-start)/2)
  done := make(chan bool)
	go func () {
		parallelRange(grain, mid, stop, f);
		done <- true
	} ()

	parallelRange(grain, start, mid, f)
	<-done
}
