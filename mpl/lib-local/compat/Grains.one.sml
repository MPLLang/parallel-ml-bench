structure Grains:
sig
  type grain = int
  val parfor: grain
  val block: grain
  val mergesort: grain
  val merge: grain
end =
struct
  type grain = int

  val parfor = CommandLineArgs.parseInt "parfor-grain" 1
  val block = CommandLineArgs.parseInt "block-grain" 100

  val merge = CommandLineArgs.parseInt "merge-grain" 100
  val mergesort = CommandLineArgs.parseInt "mergesort-grain" 10
end
