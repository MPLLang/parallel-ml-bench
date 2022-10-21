structure CLA = CommandLineArgs

structure P = ParFuncArray

structure A =
struct
  type 'a t = {start: int, len: int, data: 'a P.farray}
  type 'a array = 'a t

  fun full (a: 'a P.farray) : 'a t =
    {start = 0, len = P.length a, data = a}

  fun tabulate (n, f) : 'a t =
    full (P.tabulate (n, f))

  fun sub ({start, len, data}: 'a t, i) =
    P.sub (data, start+i)

  fun subseq ({start, len, data}: 'a t) {start=i, len=n} =
    {start=start+i, len=n, data=data}

  fun update ({start, len, data}: 'a t, i, x) =
    {start=start, len=len, data=P.update (data, start+i, x)}

  fun length ({start, len, data}: 'a t) = len
end

structure Key =
struct
  type key = int
  type t = key

  val compare = Int.compare

  fun comparePriority (k1, k2) =
    Word64.compare
      (Util.hash64_2 (Word64.fromInt k1),
       Util.hash64_2 (Word64.fromInt k2))

  val toString = Int.toString
end

structure T =
  ChunkedTreap(
    structure A = A
    structure Key = Key
    val leafSize = 16
  )

val n = CLA.parseInt "n" 10000
val nq = CLA.parseInt "nq" 100000
val nu = CLA.parseInt "nu" 10

fun bench () =
  let
    val t = SeqBasis.reduce 100 T.join (T.empty()) (0, n)
      (fn i => T.singleton (i, Util.intToString i))

    val _ =
      if n <= 50 then
        print (T.toString t ^ "\n")
      else
        ()

    fun query i =
      valOf (T.lookup t (Util.hash i mod n))

    fun queryChunk (lo, hi) =
      let
        val results = SeqBasis.tabulate 1000 (lo, hi) query
      in
        String.concatWith "" (List.tabulate (hi-lo, fn i => query(lo+i)))
      end

    fun updateLoop t i func =
      if i >= nu then
        t
      else let
        val j = Util.hash (100*i) mod n
        (* val j = i *)
      in
        updateLoop (T.updateKey t (j, func j)) (i+1) func
      end

    val (updated, queries) =
      ForkJoin.par (
        fn _ =>
          updateLoop
            (updateLoop t 0 (fn i => Util.intToString(~1)))
            0
            (fn i => Util.intToString i),

        fn _ => SeqBasis.tabulate 1 (0, Util.ceilDiv nq 100)
          (fn i => queryChunk (i*100, Int.min ((i+1)*100, nq)))
      )
  in
    (t, updated, queries)
  end

val (orig, updated, queries) = Benchmark.run "pfa-bst" bench

val _ = print (Array.sub (queries, 0) ^ "\n")
(* val _ = print (Util.summarizeArray 2 (fn s => s) queries ^ "\n") *)

val _ = GCStats.report ()
