structure CLA = CommandLineArgs

val q = CLA.parseInt "q" 10000
val n = CLA.parseInt "n" 1000000
val leaf_size = CLA.parseInt "leaf-size" 100
val impl = CLA.parseString "impl" "tree"

val _ = print ("n " ^ Int.toString n ^ "\n")
val _ = print ("q " ^ Int.toString q ^ "\n")
val _ = print ("impl " ^ impl ^ "\n")
val _ = print ("leaf-size " ^ Int.toString leaf_size ^ "\n")

structure It = IntervalTree(val leaf_size = leaf_size)

(* ==========================================================================
 * random segments
 *)

val max_size = 1000000000

fun randRange i j seed =
  i
  +
  Word64.toInt (Word64.mod
    (Util.hash64 (Word64.fromInt seed), Word64.fromInt (j - i)))

fun randSeg seed =
  let
    val p = randRange 1 max_size seed
    val space = max_size - p
    val hi = p + 1 + space div 100
  in
    (p, randRange p hi (seed + 1))
  end

(* ==========================================================================
 * input intervals and queries
 *)

val input = Seq.tabulate (fn i => randSeg (2 * i)) n

fun gen_query i =
  randRange 1 max_size (2 * n + i)

(* =========================================================================
 * two benchmark implementations: interval tree, and brute force search
 *)

fun tree_bench () =
  let
    val (t, tm) = Util.getTime (fn () => It.make_tree input)
    val _ = print ("tick:make_tree:" ^ Time.fmt 4 tm ^ "s\n")
    val (result, tm) = Util.getTime (fn () =>
      ArraySlice.full (SeqBasis.tabulate 1 (0, q) (fn i =>
        It.stab_count t (gen_query i))))
    val _ = print ("tick:  queries:" ^ Time.fmt 4 tm ^ "s\n")
  in
    result
  end


fun search_bench () =
  let
    fun search i =
      let
        val x = gen_query i
      in
        ForkJoin.reducem op+ 0 (0, Seq.length input) (fn j =>
          let val (a, b) = Seq.nth input j
          in if a <= x andalso x < b then 1 else 0
          end)
      end
  in
    ArraySlice.full (SeqBasis.tabulate 1 (0, q) search)
  end

(* ==========================================================================
 * run benchmark and show results
 *)

val bench =
  case impl of
    "tree" => tree_bench
  | "search" => search_bench
  | _ => Util.die ("Unknown -impl " ^ impl)

val result = Benchmark.run ("interval stab counts: " ^ impl) bench

val numHits = Seq.reduce op+ 0 result
val minHits = Seq.reduce Int.min (valOf Int.maxInt) result
val maxHits = Seq.reduce Int.max 0 result
val avgHits = Real.round (Real.fromInt numHits / Real.fromInt q)
val _ = print ("hits " ^ Int.toString numHits ^ "\n")
val _ = print ("min " ^ Int.toString minHits ^ "\n")
val _ = print ("avg " ^ Int.toString avgHits ^ "\n")
val _ = print ("max " ^ Int.toString maxHits ^ "\n")
