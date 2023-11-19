structure CLA = CommandLineArgs

structure I =
struct
  type t = Int64.int
  val from_int = Int64.fromInt
  val to_int = Int64.toInt
  val to_string = Int64.toString
end

structure Primes = SegmentedPrimes(I)

val n = CLA.parseInt "N" (100 * 1000 * 1000)
val block_size_factor = CLA.parseReal "block-size-factor" 8.0
val _ = print ("N " ^ Int.toString n ^ "\n")
val _ = print ("block-size-factor " ^ Real.toString block_size_factor ^ "\n")

val params = {block_size_factor = block_size_factor, report_times = true}

val msg = "generating primes up to " ^ Int.toString n

val result = Benchmark.run msg (fn _ =>
  Primes.primes_with_params params (I.from_int n))

val numPrimes = Seq.length result
val _ = print ("number of primes " ^ Int.toString numPrimes ^ "\n")
val _ = print ("result " ^ Util.summarizeArraySlice 8 I.to_string result ^ "\n")
