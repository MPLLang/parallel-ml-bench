package main

import (
  // "os"
  "fmt"
  // "time"
	// "runtime"
	"github.com/intel/forGoParallel/parallel"
)

type ParamStruct struct {
  // n, threads, rounds, warmup_rounds int
  n_buckets, oversample_stride, n_countblocks int
}

// func read_cmdline_input(args []string) (int, int, int) {
//   const expected_args int = 3
//   if num_args := len(args) ; num_args != expected_args + 1 {
//     fmt.Printf("Usage: %s <n> <threads> <rounds\n", args[0])
//     os.Exit(1);
//   }
//   return string_to_int(args[1]), string_to_int(args[2]), string_to_int(args[3])
// }

// func read_cmdline_input_struct(args []string) ParamStruct {
//   const expected_args int = 4
//   if num_args := len(args) ; num_args != expected_args + 1 {
//     fmt.Printf("Usage: %s <n> <threads> <rounds> <warmup rounds>\n", args[0])
//     os.Exit(1);
//   }

//   n := string_to_int(args[1])
//   threads := string_to_int(args[2])
//   rounds := string_to_int(args[3])
// 	warmup_rounds := string_to_int(args[4])

// 	runtime.GOMAXPROCS(threads)

//   return ParamStruct{
//     n,
//     threads * 4,
//     rounds,
// 		warmup_rounds,
//     threads * 16, // # of buckets
//     16,           // oversample stride (was 4)
//     threads * 16, // # of countblocks (was *4)
//   }
// }

func doSort(input ElementSlice) ElementSlice {
	output := make(ElementSlice, len(input))
  ps := ParamStruct{ 256, 16, 256 }
  parallel_sample_sort(input, output, ps)
	return output
}

func main() {
// Read cmdline input
	n := parseInt("n", 10000000)
  fmt.Printf("n %d\n", n)

	xs := make([]int64, n)
	parallel.Range(0, n, func(low, high int) {
		for i := low; i < high; i++ {
			xs[i] = int64(hash64(uint64(i)) % uint64(n))
		}
	})

	var result ElementSlice
	benchmarkRun("sample sort", func(){ result = doSort(xs) })

	for i := 0; i < 10; i++ {
		// result[i].Print()
    fmt.Printf("%d ", result[i])
  }
  fmt.Printf("...\n")
}
