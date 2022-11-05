structure CLA = CommandLineArgs

val elemSize = CLA.parseInt "elem-size" 100000
val numElems = CLA.parseInt "num-elems" 1000
val numTangles = CLA.parseInt "num-tangles" 10
val pEnt = CLA.parseReal "p-ent" 0.5

val _ = print ("elem-size " ^ Int.toString elemSize ^ "\n")
val _ = print ("num-elems " ^ Int.toString numElems ^ "\n")
val _ = print ("p-ent " ^ Real.toString pEnt ^ "\n")
val _ = print ("num-tangles " ^ Int.toString numTangles ^ "\n")
val _ = print ("(increase num-tangles to reduce contention, but be careful: if\n\
               \this value is too large, then entanglement becomes less likely)\n\n")

datatype 'a tree = Node of int * 'a tree * 'a tree | Leaf of 'a | Empty

fun szt Empty = 0
  | szt (Leaf _) = 1
  | szt (Node (n, _, _)) = n

fun fstt Empty = raise Fail "fstt"
  | fstt (Leaf x) = x
  | fstt (Node (_, l, _)) = fstt l

fun node (Empty, x) = x
  | node (x, Empty) = x
  | node (x, y) = Node (szt x + szt y, x, y)

datatype 'a szlist = Cons of int * 'a * 'a szlist | Nil

fun szl Nil = 0
  | szl (Cons (n, _, _)) = n

fun fstl Nil = raise Fail "fstl"
  | fstl (Cons (_, x, _)) = x

fun cons x xs = Cons (1 + szl xs, x, xs)

fun bench () =
  let
    val tangles = Vector.tabulate (numTangles, fn _ => ref Nil)

    fun pushloop tangle count curr x =
      let
        val curr' = Concurrency.cas tangle (curr, cons x curr)
        val count' = count+1
      in
        if MLton.eq (curr', curr)
        then count'
        else pushloop tangle count' curr' x
      end

    fun push i x =
      let
        val ti = Util.hash i mod numTangles
        val tangle = Vector.sub (tangles, ti)
      in
        pushloop tangle 0 (!tangle) x
      end

    fun gen i =
      PureSeq.tabulate (fn j => if j mod 2 = 0 then [()] else []) elemSize

    val mid = Real.floor (pEnt * Real.fromInt numElems)
    fun left () = SeqBasis.reduce 1 op+ 0 (0, mid) (fn i => push i (gen i))
    fun right () = SeqBasis.reduce 1 node Empty (mid, numElems) (Leaf o gen)
    
    val (failed, t) = ForkJoin.par (left, right)
    val l = !(Vector.sub (tangles, 0))

    val a = PureSeq.nth (fstl l) 0
    val b = PureSeq.nth (fstt t) 0

    val szlTotal =
      Vector.foldl (fn (tangle, acc) => acc + szl (!tangle)) 0 tangles
  in
    (szlTotal, szt t, List.length a, List.length b, failed)
  end


val (a, b, c, d, f) = Benchmark.run "tangle" bench
val _ = print (Int.toString c ^ " " ^ Int.toString d ^ "\n")
val _ = print ("tangled " ^ Int.toString a ^ "\n")
val _ = print ("ordered " ^ Int.toString b ^ "\n")
val _ = print ("contention " ^ Int.toString f ^ " (total num failed CASes)\n")
val _ = print "\n"