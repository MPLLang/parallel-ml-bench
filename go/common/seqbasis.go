package main

import (
	// "github.com/intel/forGoParallel/parallel"
)

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
	blockSums := make([]T, numBlocks)
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
	result := make([]T, n+1)
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
	blockSize := grain
	numBlocks := 1 + (n-1) / blockSize
	blockCounts := make([]int, numBlocks)
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

	offsets := scan(grain, func(a, b int) int { return a+b }, 0, blockCounts)
	total := offsets[numBlocks]

	result := make([]T, total)
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

	return result
}

func filterRange[T any](grain int, p func(int) bool, lo int, hi int, f func(int) T) []T {
	return filter(grain,
	  func (i int) bool { return p(lo+i) },
		hi-lo,
		func (i int) T { return f(lo+i) })
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
