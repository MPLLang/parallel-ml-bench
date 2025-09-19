structure CLA = CommandLineArgs
structure Seq = ArraySequence

val n = CLA.parseInt "n" (1000 * 1000 * 100)

fun __inline_always__ gen i = Real.fromInt ((Util.hash i) mod 1000 - 500) / 500.0

val input = Seq.tabulate gen n
fun __inline_always__ emit i = Seq.nth input i

fun task () = MCSS.mcss emit n

val result = Benchmark.run "mcss" task
val _ = print ("result: " ^ Real.toString result ^ "\n")