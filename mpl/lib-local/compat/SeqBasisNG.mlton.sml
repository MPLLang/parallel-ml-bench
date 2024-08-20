structure SeqBasisNG:
sig
  val tabulate: (int * int) -> (int -> 'a) -> 'a array

  val foldl: ('b * 'a -> 'b) -> 'b -> (int * int) -> (int -> 'a) -> 'b

  val foldr: ('b * 'a -> 'b) -> 'b -> (int * int) -> (int -> 'a) -> 'b

  val reduce: ('a * 'a -> 'a) -> 'a -> (int * int) -> (int -> 'a) -> 'a

  val scan: ('a * 'a -> 'a)
            -> 'a
            -> (int * int)
            -> (int -> 'a)
            -> 'a array (* length N+1, for both inclusive and exclusive scan *)

  val filter: (int * int) -> (int -> 'a) -> (int -> bool) -> 'a array

  val tabFilter: (int * int) -> (int -> 'a option) -> 'a array
end =
struct

  structure A = Array
  structure AS = ArraySlice

  fun upd a i x = A.update (a, i, x)
  fun nth a i = A.sub (a, i)

  fun parfor (i: int, j: int) (f: int -> unit) =
      Parfor.pareduce (i, j) () (fn (i, ()) => f i) (fn ((), ()) => ())
  val par = ForkJoin.par
  val allocate = ForkJoin.alloc


  fun tabulate (lo, hi) f =
    let
      val n = hi - lo
      val result = allocate n
    in
      if lo = 0 then parfor (0, n) (fn i => upd result i (f i))
      else parfor (0, n) (fn i => upd result i (f (lo + i)));

      result
    end


  fun foldl g b (lo, hi) f =
    if lo >= hi then b
    else let val b' = g (b, f lo) in foldl g b' (lo + 1, hi) f end


  fun foldr g b (lo, hi) f =
    if lo >= hi then
      b
    else
      let
        val hi' = hi - 1
        val b' = g (b, f hi')
      in
        foldr g b' (lo, hi') f
      end


  fun reduce g b (lo, hi) f =
    Parfor.pareduce (lo, hi) b (fn (i, a) => g (a, f i)) g

  fun reduce' (b: 'a) (lo: int, hi: int) (f: int * 'a -> 'a) =
    if lo >= hi then
      b
    else
      reduce' (f (lo, b)) (lo + 1, hi) f


  fun scan (g: 'a * 'a -> 'a) (b: 'a) (lo: int, hi: int) (f: int -> 'a): 'a array =
      let val n = hi - lo
          val result = allocate (n + 1)
          fun bump ((j, b), x) =
              (upd result j b; (j + 1, g (b, x)))
          val (_, total) = foldl bump (0, b) (lo, hi) f
          val _ = upd result n total
      in
        result
      end

  fun filter (lo: int, hi: int) (f: int -> 'a) (g: int -> bool): 'a array =
    let val n = hi - lo
        val counts = reduce' 0 (0, n) (fn (i, c) => if g i then c + 1 else c)
        val result = allocate counts
        fun store (i, c) =
            if g i then (upd result c (f i); c + 1) else c
        val _ = reduce' 0 (0, n) store
    in
      result
    end

  fun tabFilter (lo: int, hi: int) (f: int -> 'a option): 'a array =
    let val n = hi - lo
        fun count (i, c) = if Option.isSome (f i) then c + 1 else c
        val counts = reduce' 0 (0, n) count
        val result = allocate counts
        fun store (i, c) =
            case f i of
                NONE => c
              | SOME b => (upd result c b; c + 1)
        val _ = reduce' 0 (0, n) store
    in
      result
    end

end
