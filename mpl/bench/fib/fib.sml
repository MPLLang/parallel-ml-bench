structure CLA = CommandLineArgs

val grain = CLA.parseInt "grain" 20

fun sfib n =
  if n <= 1 then n else sfib (n-1) + sfib (n-2)

fun fib n =
  if n <= grain then sfib n
  else
    let
      val (x,y) = ForkJoin.par (fn _ => fib (n-1), fn _ => fib (n-2))
    in
      x + y
    end

val n = CLA.parseInt "N" 39
val _ = print ("N " ^ Int.toString n ^ "\n")

val result = Benchmark.run "running fib" (fn _ => fib n)

val _ = print ("result " ^ Int.toString result ^ "\n")

val doCheck = CLA.parseFlag "check"
val _ =
  if not doCheck then
    print ("do --check to check correctness\n")
  else if result = sfib n then
    print ("correct? yes\n")
  else
    print ("correct? no\n")

val _ = GCStats.report ()
