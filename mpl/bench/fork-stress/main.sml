structure CLA = CommandLineArgs

fun bench width length =
  let
    (* Just a little garbage computation to stress calling `par` a lot.
     * The goal is for the overall work to be essentially 0 except for `par`.
     *)
    fun loop lo hi (x: Word64.word) =
      if hi - lo <= 0w1 then
        x + 0w1
      else
        let
          val halfmask = Word64.<< (0w1, 0w32) - 0w1
          val left = Word64.>> (x, 0w32)
          val right = Word64.andb (x, halfmask)

          val mid = lo + Word64.>> (hi - lo, 0w1)
          val (left', right') =
            ForkJoin.par (fn () => loop lo mid left, fn () => loop mid hi right)
          val x' = Word64.orb (Word64.<< (left', 0w32), right')
        in
          Word64.xorb (x, x')
        end
  in
    Util.loop (0, length) 0w0 (fn (x, _) => loop 0w0 (Word64.fromInt width) x)
  end

(* approximately `width*length` calls to par in total *)
val width = CLA.parseInt "width" 1000
val length = CLA.parseInt "length" 5000
val _ = print ("width " ^ Int.toString width ^ "\n")
val _ = print ("length " ^ Int.toString length ^ "\n")

val result = Benchmark.run "fork-stress" (fn () => bench width length)
val _ = print ("result " ^ Word64.toString result ^ "\n")
