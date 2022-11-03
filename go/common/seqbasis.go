package main

import (
	// "github.com/intel/forGoParallel/parallel"
	"golang.org/x/exp/constraints"
	"time"
	"sync/atomic"
	"unsafe"
	// "fmt"
)

func tabulate[T any](grain int, n int, f func(int) T) []T {
	result := make([]T, n)
	parallelRange(grain, 0, n, func(lo, hi int) {
		for i := lo; i < hi; i++ {
			result[i] = f(i)
		}
	})
	return result
}

func scan[T any](grain int, f func(T,T) T, z T, input []T) []T {
	n := len(input)

	if n <= grain {
		result := make([]T, n+1)
		acc := z
		for i := 0; i < n; i++ {
			result[i] = acc
			acc = f(acc, input[i])
		}
		result[len(input)] = acc
		return result
	}

  blockSize := grain
	numBlocks := 1 + (n-1) / blockSize
	// blockSums := make([]T, numBlocks)
	blockSums := arrayAlloc[T](numBlocks)
	parallelRange(1, 0, numBlocks, func(bLo, bHi int) {
		for b := bLo; b < bHi; b++ {
			start := b*blockSize
			stop := min(n, (b+1)*blockSize)
			acc := z
			for i := start; i < stop; i++ {
				acc = f(acc, input[i])
			}
			blockSums[b] = acc
		}
	})

	partials := scan[T](grain, f, z, blockSums)
	result := arrayAlloc[T](n+1)
	parallelRange(1, 0, numBlocks, func(bLo, bHi int) {
		for b := bLo; b < bHi; b++ {
			start := b*blockSize
			stop := min(n, (b+1)*blockSize)
			acc := partials[b]
			for i := start; i < stop; i++ {
				result[i] = acc
				acc = f(acc, input[i])
			}
			blockSums[b] = acc
		}
	})

	result[n] = partials[numBlocks]
	return result
}


func filter[T any](grain int, p func(int) bool, n int, f func(int) T) []T {
	tm := time.Now()

	blockSize := grain
	numBlocks := 1 + (n-1) / blockSize
	// blockCounts := make([]int, numBlocks)
	blockCounts := arrayAlloc[int](numBlocks)
	tm = tickSince(tm, "filter:alloc")
	parallelRange(1, 0, numBlocks, func(bLo, bHi int) {
		for b := bLo; b < bHi; b++ {
			start := b*blockSize
			stop := min(n, (b+1)*blockSize)
			count := 0
			for i := start; i < stop; i++ {
				if p(i) {
					count++
				}
			}
			blockCounts[b] = count
		}
	})

	tm = tickSince(tm, "filter:block-counts")

	offsets := scan(grain, func(a, b int) int { return a+b }, 0, blockCounts)
	total := offsets[numBlocks]
	tm = tickSince(tm, "filter:scan-offsets")

	result := arrayAlloc[T](total)
	tm = tickSince(tm, "filter:alloc-output")
	parallelRange(1, 0, numBlocks, func(bLo, bHi int) {
		for b := bLo; b < bHi; b++ {
			start := b*blockSize
			stop := min(n, (b+1)*blockSize)
			j := offsets[b]
			for i := start; i < stop; i++ {
				if p(i) {
					result[j] = f(i)
					j++
				}
			}
		}
	})
	tm = tickSince(tm, "filter:fill-output")

	return result
}


func intFilter(grain int, p func(int) bool, n int, f func(int) int) []int {
	tm := time.Now()

	blockSize := grain
	numBlocks := 1 + (n-1) / blockSize
	// blockCounts := make([]int, numBlocks)
	blockCounts := arrayAlloc[int](numBlocks)
	tm = tickSince(tm, "intFilter:alloc")
	parallelRange(1, 0, numBlocks, func(bLo, bHi int) {
		for b := bLo; b < bHi; b++ {
			start := b*blockSize
			stop := min(n, (b+1)*blockSize)
			count := 0
			for i := start; i < stop; i++ {
				if p(i) {
					count++
				}
			}
			blockCounts[b] = count
		}
	})

	tm = tickSince(tm, "intFilter:block-counts")

	offsets := scan(grain, func(a, b int) int { return a+b }, 0, blockCounts)
	total := offsets[numBlocks]
	tm = tickSince(tm, "intFilter:scan-offsets")

	result := arrayAlloc[int](total)
	tm = tickSince(tm, "intFilter:alloc-output")
	parallelRange(1, 0, numBlocks, func(bLo, bHi int) {
		for b := bLo; b < bHi; b++ {
			start := b*blockSize
			stop := min(n, (b+1)*blockSize)
			j := offsets[b]
			for i := start; i < stop; i++ {
				if p(i) {
					result[j] = f(i)
					j++
				}
			}
		}
	})
	tm = tickSince(tm, "intFilter:fill-output")

	return result
}


func filterRange[T any](grain int, p func(int) bool, lo int, hi int, f func(int) T) []T {
	return filter(grain,
	  func (i int) bool { return p(lo+i) },
		hi-lo,
		func (i int) T { return f(lo+i) })
}


func filterArray[T any](grain int, p func(T) bool, data []T) []T {
	return filter(grain,
	  func (i int) bool { return p(data[i]) },
		len(data),
		func (i int) T { return data[i] })
}


func reduce[T any](grain int, g func(T, T) T, z T, lo, hi int, f func(int) T) T {
	if hi-lo <= grain {
		acc := z
		for i := lo; i < hi; i++ {
			acc = g(acc, f(i))
		}
		return acc
	}

	mid := lo + ((hi-lo)/2)
  done := make(chan bool)
	var right T
	go func () {
		right = reduce(grain, g, z, mid, hi, f)
		done <- true
	} ()

	left := reduce(grain, g, z, lo, mid, f)
	<-done

	return g(left, right)
}


func Cas[T any](slot **T, old *T, new *T) bool {
	return atomic.CompareAndSwapPointer(
		(*unsafe.Pointer)(unsafe.Pointer(slot)),
		unsafe.Pointer(old),
		unsafe.Pointer(new),
	)
}


func accumPut[T any](slot **T, g func(T, T) T, x T) {
	// fmt.Print("accumPut ", slot, x, "\n")
	unsafeSlot := (*unsafe.Pointer)(unsafe.Pointer(slot))
	for {
		curr := (*T)(atomic.LoadPointer(unsafeSlot))
		desired := g(*curr, x)
		if Cas(slot, curr, &desired) {
			// fmt.Print("DONE: accumPut ", slot, x, "\n")
			return
		}
	}
}


func commutativeAccum[T any](grain int, g func(T, T) T, z T, lo, hi int, f func(int) T) T {
	if hi-lo <= grain {
		acc := z
		for i := lo; i < hi; i++ {
			acc = g(acc, f(i))
		}
		return acc
	}

  // fmt.Print("hello1\n")

  var total **T
  addr_z := &z
	total = &addr_z

  n := hi - lo
  blockSize := grain
	numBlocks := 1 + (n-1) / blockSize
	// fmt.Print("blockSize ", blockSize, "numBlocks ", numBlocks, "\n")
	parallelRange(1, 0, numBlocks, func(bLo, bHi int) {
		for b := bLo; b < bHi; b++ {
			// fmt.Print("block ", b, "\n")
			start := lo + b*blockSize
			stop := min(hi, start + blockSize)
			acc := z
			for i := start; i < stop; i++ {
				acc = g(acc, f(i))
			}
			accumPut(total, g, acc)
		}
	})

	return **total
}


// ===========================================================================

/*
let search cmp s x =
  let rec loop lo hi =
    match hi - lo with
    | 0 -> lo
    | n ->
      let mid = lo + n / 2 in
      let pivot = Seq.get s mid in
      let c = cmp x pivot in
      if c < 0 then
        (* less *)
        loop lo mid
      else if c = 0 then
        (* equal *)
        mid
      else
        (* greater *)
        loop (mid+1) hi
  in
  loop 0 (Seq.length s)
*/

func binarySearch[T constraints.Ordered](s []T, x T) int {
	lo := 0
	hi := len(s)

	for ; lo < hi; {
		n := hi-lo
		mid := lo + n/2
		pivot := s[mid]
		if x < pivot {
			hi = mid
		} else if x == pivot {
			return mid
		} else {
			lo = mid+1
		}
	}

	return lo
}

func writeMergeSerial[T constraints.Ordered](s1, s2, t []T) {
	n1 := len(s1)
	n2 := len(s2)
	i1 := 0
	i2 := 0
	j := 0

	for ; i1 < n1 && i2 < n2; j++ {
		x1 := s1[i1]
		x2 := s2[i2]
		if x1 < x2 {
			t[j] = x1
			i1++
		} else {
			t[j] = x2
			i2++
		}
	}

	for ; i1 < n1; j++ {
		t[j] = s1[i1]
		i1++
	}

	for ; i2 < n2; j++ {
		t[j] = s2[i2]
		i2++
	}
}

func writeMerge[T constraints.Ordered](s1, s2, t []T) {
	n1 := len(s1)
	n2 := len(s2)

	if n1+n2 <= 5000 {
		writeMergeSerial(s1, s2, t)
		return
	}

	if n1 == 0 {
		parallelRange(5000, 0, n2, func (lo, hi int) {
			for i := lo; i < hi; i++ {
				t[i] = s2[i]
			}
		})
		return
	}

	mid1 := n1 / 2
	pivot := s1[mid1]
	mid2 := binarySearch(s2, pivot)

	l1 := s1[:mid1]
	r1 := s1[(mid1+1):]
	l2 := s2[:mid2]
	r2 := s2[mid2:]

	t[mid1+mid2] = pivot
	tl := t[:(mid1+mid2)]
	tr := t[(mid1+mid2+1):]
	pardo(func(){ writeMerge(l1, l2, tl) },
	      func(){ writeMerge(r1, r2, tr) })
}
