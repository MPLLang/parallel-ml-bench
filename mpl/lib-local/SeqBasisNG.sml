structure SeqBasisNG:
sig
  val tabulate: (int * int) -> (int -> 'a) -> 'a array

  val foldl: ('b * 'a -> 'b)
          -> 'b
          -> (int * int)
          -> (int -> 'a)
          -> 'b

  val foldr: ('b * 'a -> 'b)
          -> 'b
          -> (int * int)
          -> (int -> 'a)
          -> 'b

  val reduce: ('a * 'a -> 'a)
           -> 'a
           -> (int * int)
           -> (int -> 'a)
           -> 'a

  val scan: ('a * 'a -> 'a)
         -> 'a
         -> (int * int)
         -> (int -> 'a)
         -> 'a array  (* length N+1, for both inclusive and exclusive scan *)

  val filter: (int * int)
           -> (int -> 'a)
           -> (int -> bool)
           -> 'a array

  val tabFilter: (int * int)
              -> (int -> 'a option)
              -> 'a array
end =
struct

  structure A = Array
  structure AS = ArraySlice

  (*
  fun upd a i x = Unsafe.Array.update (a, i, x)
  fun nth a i   = Unsafe.Array.sub (a, i)
  *)

  fun upd a i x = A.update (a, i, x)
  fun nth a i   = A.sub (a, i)

  val parfor = ForkJoinNG.parfor
  val par = ForkJoin.par
  val allocate = ForkJoin.alloc


  fun tabulate (lo, hi) f =
    let
      val n = hi-lo
      val result = allocate n
    in
      if lo = 0 then
        parfor (0, n) (fn i => upd result i (f i))
      else
        parfor (0, n) (fn i => upd result i (f (lo+i)));

      result
    end


  fun foldl g b (lo, hi) f =
    if lo >= hi then b else
    let
      val b' = g (b, f lo)
    in
      foldl g b' (lo+1, hi) f
    end


  fun foldr g b (lo, hi) f =
    if lo >= hi then b else
    let
      val hi' = hi-1
      val b' = g (b, f hi')
    in
      foldr g b' (lo, hi') f
    end


  fun reduce g b (lo, hi) f =
    let
      fun loop lo hi () =
        if hi-lo <= OneTrueGrain.asWord64 then
          foldl g b (Word64.toIntX lo, Word64.toIntX hi) f
        else
          let
            val half = Word64.>> (hi-lo, 0w1)
            val mid = lo + half
          in
            g (ForkJoin.par (loop lo mid, loop mid hi))
          end
    in
      loop (Word64.fromInt lo) (Word64.fromInt hi) ()
    end


  val BLOCK_SIZE = CommandLineArgs.parseInt "seq-basis-ng-block-size" 1000


  fun scan g b (lo, hi) (f : int -> 'a) =
    if hi - lo <= BLOCK_SIZE then
      let
        val n = hi - lo
        val result = allocate (n+1)
        fun bump ((j,b),x) = (upd result j b; (j+1, g (b, x)))
        val (_, total) = foldl bump (0, b) (lo, hi) f
      in
        upd result n total;
        result
      end
    else
      let
        val n = hi - lo
        val k = BLOCK_SIZE
        val m = 1 + (n-1) div k (* number of blocks *)
        val sums = tabulate (0, m) (fn i =>
          let val start = lo + i*k
          in foldl g b (start, Int.min (start+k, hi)) f
          end)
        val partials = scan g b (0, m) (nth sums)
        val result = allocate (n+1)
      in
        parfor (0, m) (fn i =>
          let
            fun bump ((j,b),x) = (upd result j b; (j+1, g (b, x)))
            val start = lo + i*k
          in
            foldl bump (i*k, nth partials i) (start, Int.min (start+k, hi)) f;
            ()
          end);
        upd result n (nth partials m);
        result
      end


  fun filter (lo, hi) f g =
    let
      val n = hi - lo
      val k = BLOCK_SIZE
      val m = 1 + (n-1) div k (* number of blocks *)
      fun count (i, j) c =
        if i >= j then c
        else if g i then count (i+1, j) (c+1)
        else count (i+1, j) c
      val counts = tabulate (0, m) (fn i =>
        let val start = lo + i*k
        in count (start, Int.min (start+k, hi)) 0
        end)
      val offsets = scan op+ 0 (0, m) (nth counts)
      val result = allocate (nth offsets m)
      fun filterSeq (i, j) c =
        if i >= j then ()
        else if g i then (upd result c (f i); filterSeq (i+1, j) (c+1))
        else filterSeq (i+1, j) c
    in
      parfor (0, m) (fn i =>
        let val start = lo + i*k
        in filterSeq (start, Int.min (start+k, hi)) (nth offsets i)
        end);
      result
    end


  fun tabFilter (lo, hi) (f : int -> 'a option) =
    let
      val n = hi - lo
      val k = BLOCK_SIZE
      val m = 1 + (n-1) div k (* number of blocks *)
      val tmp = allocate n

      fun filterSeq (i,j,k) =
        if (i >= j) then k
        else case f i of
           NONE => filterSeq(i+1, j, k)
         | SOME v => (A.update(tmp, k, v); filterSeq(i+1, j, k+1))

      val counts = tabulate (0, m) (fn i =>
        let val last = filterSeq (lo + i*k, lo + Int.min((i+1)*k, n), i*k)
        in last - i*k
        end)

      val outOff = scan op+ 0 (0, m) (fn i => A.sub (counts, i))
      val outSize = A.sub (outOff, m)

      val result = allocate outSize
    in
      parfor (0, m) (fn i =>
        let
          val soff = i * k
          val doff = A.sub (outOff, i)
          val size = A.sub (outOff, i+1) - doff
        in
          Util.for (0, size) (fn j =>
            A.update (result, doff+j, A.sub (tmp, soff+j)))
        end);
      result
    end

end
