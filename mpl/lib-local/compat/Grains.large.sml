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
  val parfor = CommandLineArgs.parseInt "parfor-grain" 5000
  val merge = CommandLineArgs.parseInt "merge-grain" 1000
  val mergesort = CommandLineArgs.parseInt "mergesort-grain" 10
  val block = CommandLineArgs.parseInt "block-grain" 1000
end