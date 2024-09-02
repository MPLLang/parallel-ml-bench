structure CLA = CommandLineArgs

val n = CLA.parseInt "n" (1000 * 1000 * 100)
val version = CLA.parseInt "v" 1

val scan = if version = 2 then SeqBasisNG.scan2 else SeqBasisNG.scan

fun task () =
    let val arr = scan op+ 0 (0, n) (fn i => i) in
      Array.sub (arr, n - 5)
    end

val result = Benchmark.run "scan-stress" task
val _ = print ("result " ^ Int.toString result ^ "\n")
