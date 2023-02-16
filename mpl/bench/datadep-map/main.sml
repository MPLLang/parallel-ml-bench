structure CLA = CommandLineArgs

fun seqfib n =
  if n < 2 then n else seqfib (n - 1) + seqfib (n - 2)
fun parfib n =
  if n < 15 then seqfib n
  else op+ (ForkJoin.par (fn _ => parfib (n - 1), fn _ => parfib (n - 2)))


val inputs = [(1000, fn i => parfib 20)]

val result = Benchmark.run "..." (fn _ =>
  SeqNG.tabulate (fn _ => parfib 20) 1000)
val _ = print (Util.summarizeArraySlice 8 Int.toString result ^ "\n")
