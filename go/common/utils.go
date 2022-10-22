package main

import (
  "os"
	"io/ioutil"
  "fmt"
  "strconv"
  "golang.org/x/exp/constraints"
	"time"
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

// func unsignedMod(d, m int64) int64 {
// 	r := d % m
// 	if (r < 0 && m > 0) || (r > 0 && m < 0) {
// 		return r + m
// 	}
// 	return r
// }

func unsignedMod(a, b int64) int64 {
	r := a % b
	if r < 0 {
		return r + b
	}
	return r
}

func intMod(a, b int) int {
	r := a % b
	if r >= 0 { return r }
	if b < 0 { return r - b }
	return r + b
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



// ==========================================================================


func tokenGenerator(s []byte, isSpace func(byte) bool) (int, func(int)string) {
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

	makeString := func(i int) string {
		start := ids[2*i]
		stop := ids[2*i+1]
    return string(s[start:stop])
	}

	return count, makeString
}


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


// ==========================================================================

// func arrayAlloc[T any](n int) []T {
// 	if (n < 100000) {
// 		return make([]T, n)
// 	}

// 	var result []T
// 	tm := getTime(func() { result = make([]T, n) })
// 	fmt.Printf("make([]%T,%d): %.3fs\n", *new(T), n, tm)
// 	return result
// }


func arrayAlloc[T any](n int) []T {
	return make([]T, n)
}


func tickSince(t time.Time, msg string) time.Time {
	newt := time.Now()
	diff := newt.Sub(t).Seconds()
	fmt.Printf("tick:%s %.3fs\n", msg, diff)
	return newt
}
