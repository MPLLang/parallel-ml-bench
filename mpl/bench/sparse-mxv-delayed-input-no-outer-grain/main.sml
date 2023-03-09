structure CLA = CommandLineArgs
structure Seq = ArraySequence
structure DS = DelayedSeq
structure G = AdjacencyGraph(Int)

val infile = CLA.parseString "infile" ""

val (mat, vec, check) =
  if infile <> "" then
    Util.die
      "sparse-mxv-delayed-input-no-outer-grain: -infile ... not supported"
  else
    let
      val n = CLA.parseInt "n" (1000 * 1000 * 100)
      val rowLen = CLA.parseInt "row-len" 100
      val numRows = n div rowLen

      val _ = print ("n " ^ Int.toString n ^ "\n")
      val _ = print ("row-len " ^ Int.toString rowLen ^ "\n")
      val _ = print ("(num rows: " ^ Int.toString numRows ^ ")\n")

      val vec = DS.tabulate (fn i => 1.0) numRows

      fun gen i j =
        ((Util.hash (i * rowLen + j) mod numRows), 1.0)

      val mat =
        DS.tabulate (fn i => DS.tabulate (fn j => gen i j) rowLen) numRows

      fun check result =
        let
          fun closeEnough (a, b) =
            Real.< (Real.abs (a - b), 0.000001)
          val correct = DS.reduce (fn (a, b) => a andalso b) true
            (DS.tabulate
               (fn i => closeEnough (Seq.nth result i, Real.fromInt rowLen))
               numRows)
        in
          if correct then print ("correct? yes\n") else print ("correct? no\n")
        end
    in
      (mat, vec, check)
    end


val doCheck = CLA.parseFlag "check"


fun parfor (lo, hi) f =
  let
    val w2i = Word64.toIntX
    val i2w = Word64.fromInt

    fun loop lo hi =
      if lo + 0w1 = hi then
        f (w2i lo)
      else
        let
          val half = Word64.>> (hi - lo, 0w1)
          val mid = lo + half
        in
          ForkJoin.par (fn _ => loop lo mid, fn _ => loop mid hi);
          ()
        end
  in
    if lo >= hi then () else loop (i2w lo) (i2w hi)
  end


fun tabulate n f =
  let
    val result = ForkJoin.alloc n
  in
    parfor (0, n) (fn i => Array.update (result, i, f i));
    ArraySlice.full result
  end


fun sparseMxV (mat: (int * real) DS.t DS.t) (vec: real DS.t) =
  let
    fun f (i, x) =
      (DS.nth vec i) * x
    fun rowSum r =
      SeqBasis.reduce 5000 op+ 0.0 (0, DS.length r) (fn i => f (DS.nth r i))
  in
    tabulate (DS.length mat) (fn i => rowSum (DS.nth mat i))
  end

fun task () = sparseMxV mat vec

val result = Benchmark.run "sparse-mxv" task
val _ = if not doCheck then () else check result
