structure CLA = CommandLineArgs

val n = CLA.parseInt "n" (1000 * 1000 * 10)
val par = CLA.parseBool "par" true


val combine = Word64.+
val zero = 0w0

fun task () = ForkJoin.reducem combine zero (0, n) (fn _ => 0w1)
val result = Benchmark.run "par-loop" task
val _ = print ("result: " ^ Word64.fmt StringCvt.DEC result ^ "\n")

