structure Grains:
sig
  type grain = int
  val parfor: grain
  val merge: grain
  val mergesort: grain
  val block: grain
end =
struct
  type grain = int
  val parfor = CommandLineArgs.parseInt "parfor-grain" 32
  val merge = CommandLineArgs.parseInt "merge-grain" 400
  val mergesort = CommandLineArgs.parseInt "mergesort-grain" 10
  val block = CommandLineArgs.parseInt "block-grain" 100
end