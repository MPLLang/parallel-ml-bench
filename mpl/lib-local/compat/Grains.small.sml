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

  val parforG = CommandLineArgs.parseInt "parfor-grain" 32
  val blockG = CommandLineArgs.parseInt "block-grain" 100

  fun parfor _ = parforG
  fun block _ = blockG

  val merge = CommandLineArgs.parseInt "merge-grain" 400
  val mergesort = CommandLineArgs.parseInt "mergesort-grain" 10
end
