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

  fun parfor _ = parforG
  fun block _ = blockG

  val merge = CommandLineArgs.parseInt "merge-grain" 1000
  val mergesort = CommandLineArgs.parseInt "mergesort-grain" 10
end