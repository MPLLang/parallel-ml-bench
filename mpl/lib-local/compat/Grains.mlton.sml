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

  val maxInt = Option.getOpt (Int.maxInt, 2147483647)

  val parfor = CommandLineArgs.parseInt "parfor-grain" maxInt
  val block = CommandLineArgs.parseInt "block-grain" maxInt

  val merge = CommandLineArgs.parseInt "merge-grain" maxInt
  val mergesort = CommandLineArgs.parseInt "mergesort-grain" maxInt
end
