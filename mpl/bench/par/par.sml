fstructure CLA = CommandLineArgs

val N = CLA.parseInt "N" (1000 * 1000)



fun task () = Util.loop (0, N) 0w0 ( fn (acc, i) =>
  let
    val iw = Word64.fromInt i
    val (a, b) = ForkJoin.par
      (fn () => Word64.xorb (acc, iw),           
       fn () => Word64.andb (acc, 0w2*iw + 0w1)) 
  in
    a + b
  end)
val result = Benchmark.run "par" task
val _ = print ("result: " ^ Word64.fmt StringCvt.DEC result ^ "\n")