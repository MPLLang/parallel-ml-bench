structure Grains:
sig
  type grain = int
  val parfor: int -> grain
  val block: int -> grain

  val mergesort: grain
  val merge: grain
end =
struct
  type grain = int

  val parforG = CommandLineArgs.parseInt "parfor-grain" 5000
  val blockG = CommandLineArgs.parseInt "block-grain" 1000

  val P = Concurrency.numberOfProcessors

  fun parfor n =
    Int.max (1, Int.min (parforG, n div (8 * P)))
  fun block n =
    Int.max (2, Int.min (blockG, n div (8 * P)))

  val merge = CommandLineArgs.parseInt "merge-grain" 1000
  val mergesort = CommandLineArgs.parseInt "mergesort-grain" 10
end
