package main

import (
  "fmt"
	"unsafe"
	"sync/atomic"
	"errors"
	"math"
)

func stringCAS(slot **string, old *string, new *string) bool {
	return atomic.CompareAndSwapPointer(
		(*unsafe.Pointer)(unsafe.Pointer(slot)),
		unsafe.Pointer(old),
		unsafe.Pointer(new),
	)
}


func hashElem(elem string) int {
	// choosing this to line up with OCaml's 63-bit integers
	maxInt63 := uint64(4611686018427387903)
	n := min(32, len(elem))
	h := uint64(7)
	for i := 0; i < n; i++ {
		h = 31*h + uint64(elem[i])
	}
	return int(hash64(h % maxInt63) % maxInt63)
}


type Hashset struct {
	maxload float64
	data [](*string)
}


func makeHashSet(capacity int, maxload float64) Hashset {
	result := Hashset {
		maxload: maxload,
		data: tabulate(5000, capacity, func (i int) *string { return nil }),
	}
	return result
}


func (h Hashset) Size() int {
	return reduce(
		5000, 
		func (a, b int) int { return a+b },
		0,
		0, len(h.data),
		func (i int) int {
			if h.data[i] == nil {
				return 0
			} else {
				return 1
			}},
	)
}


func (h Hashset) Capacity() int {
	return len(h.data)
}


func (h Hashset) Insert(x string) (bool, error) {
	n := h.Capacity()
	probes := 0
	tolerance := 2 * int(math.Ceil(1.0 / (1.0 - h.maxload)))
	i := intMod(hashElem(x), n)
	for {
		if probes >= tolerance {
			return false, errors.New("Hashset is full!")
		}

		if i >= n { i = 0 }
		curr := h.data[i]
		if curr != nil {
			if *curr == x { return false, nil }
		} else {
			// slot is empty
			if stringCAS(&(h.data[i]), curr, &x) {
				return true, nil
			} else {
				// contention! try again
				continue
			}
		}

		i++
	  probes++
	}
}


func (h Hashset) Resize() Hashset {
	newcap := 2 * h.Capacity()
	newh := makeHashSet(newcap, h.maxload)
	parallelRange(1000, 0, h.Capacity(), func (lo, hi int) {
		for i := lo; i < hi; i++ {
			if h.data[i] != nil {
				newh.Insert(*(h.data[i]))
			}
		}
	})

	return newh
}


func (h Hashset) Compact() []string {
	sz := h.Size()
	result := make([]string, sz)
	j := 0
	for i := 0; i < h.Capacity(); i++ {
		if h.data[i] != nil {
			result[j] = *(h.data[i])
			j++
		}
	}
	if j != sz {
		panic(errors.New("Hashset Compact size mismatch"));
	}
	return result
}


func dedup(numElems int, makeElem func(int)string) Hashset {

  initialCap := 1000
	maxload := 0.75

	bucketSize := 10000
	numBuckets := 1 + (numElems-1) / bucketSize
	bucketStart := func (b int) int { return b*bucketSize }
	bucketEnd := func (b int) int { return min((b+1)*bucketSize, numElems) }
	bucketState := tabulate(1000, numBuckets, bucketStart)
	bucketsTodo := tabulate(1000, numBuckets, func(b int) int { return b })

	h := makeHashSet(initialCap, maxload)

	for {
		fmt.Printf("num todo: %d\n", len(bucketsTodo))
		fmt.Printf("todo: ")
		for i := 0; i < min(10, len(bucketsTodo)); i++ {
			// strings[i].Print()
			fmt.Printf("%d ", bucketsTodo[i])
		}
		fmt.Printf("\n")

		parallelRange(1, 0, len(bucketsTodo), func (lo, hi int) {
			for i := lo; i < hi; i++ {
				b := bucketsTodo[i]
				start := bucketState[b]
				end := bucketEnd(b)

				j := start
				for j < end {
					_, err := h.Insert(makeElem(j))
					if err != nil { break }
					j++
				}
				bucketState[b] = j
			}
		})

		bucketsTodo = filterArray(5000,
		  func (b int) bool { return bucketState[b] < bucketEnd(b) },
			bucketsTodo)

		if len(bucketsTodo) == 0 { break }
		h = h.Resize()
	}

	return h
}


func main() {
	path := parseString("infile", "file.txt")
  fmt.Printf("infile %s\n", path)

	var contents []byte
	tm := getTime(func() { contents = readFileContents(path) })
	fmt.Printf("read file in %.3fs\n", tm);

	var numElems int
	var makeElem func(int) string
	tm = getTime(func() {
		numElems, makeElem = tokenGenerator(contents, isSpace)
	})
	fmt.Printf("tokenized in %.3fs\n", tm);

  var result Hashset
	benchmarkRun("dedup", func(){ result = dedup(numElems, makeElem) })

  // var xx *string
	// A := "A"
	// B := "B"
	// C := "C"
	// xx = nil
  // success1 := stringCAS(&xx, nil, &A)
	// fmt.Printf("cas? %t %s\n", success1, *xx)
	// success2 := stringCAS(&xx, nil, &B)
	// fmt.Printf("cas? %t %s\n", success2, *xx)
	// success3 := stringCAS(&xx, &A, &C)
	// fmt.Printf("cas? %t %s\n", success3, *xx)

	strings := result.Compact()

  fmt.Printf("unique %d\n", len(strings))
	for i := 0; i < 10; i++ {
		// strings[i].Print()
    fmt.Printf("%s ", strings[i])
  }
  fmt.Printf("...\n")
}
