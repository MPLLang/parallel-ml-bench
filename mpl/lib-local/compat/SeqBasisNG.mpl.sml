structure SeqBasisNG:
sig
  val tabulate: (int * int) -> (int -> 'a) -> 'a array

  val foldl: ('b * 'a -> 'b) -> 'b -> (int * int) -> (int -> 'a) -> 'b

  val foldr: ('b * 'a -> 'b) -> 'b -> (int * int) -> (int -> 'a) -> 'b

  val reduce: ('a * 'a -> 'a) -> 'a -> (int * int) -> (int -> 'a) -> 'a

  val parfor: (int * int) -> (int -> unit) -> unit

  val scan: ('a * 'a -> 'a)
            -> 'a
            -> (int * int)
            -> (int -> 'a)
            -> 'a array (* length N+1, for both inclusive and exclusive scan *)
  (*val scan2: ('a * 'a -> 'a)
            -> 'a
            -> (int * int)
            -> (int -> 'a)
            -> 'a array*) (* length N+1, for both inclusive and exclusive scan *)

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

  fun scan g b (lo, hi) (f: int -> 'a) =
    if hi - lo <= Grains.block then
      let
        val n = hi - lo
        val result = allocate (n + 1)
        fun bump ((j, b), x) =
          (upd result j b; (j + 1, g (b, x)))
        val (_, total) = foldl bump (0, b) (lo, hi) f
      in
        upd result n total;
        result
      end
    else
      let
        val n = hi - lo
        val k = Grains.block
        val m = 1 + (n - 1) div k (* number of blocks *)
        val sums = tabulate (0, m) (fn i =>
          let val start = lo + i * k
          in reduce g b (start, Int.min (start + k, hi)) f
          end)
        val partials = scan g b (0, m) (nth sums)
        val result = allocate (n + 1)
      in
        parfor (0, m) (fn i =>
          let
            fun bump ((j, b), x) =
              (upd result j b; (j + 1, g (b, x)))
            val start = lo + i * k
          in
            foldl bump (i * k, nth partials i) (start, Int.min (start + k, hi))
              f;
            ()
          end);
        upd result n (nth partials m);
        result
      end

  (*fun scan2 (add: 'a * 'a -> 'a) (b: 'a) (i: int , j: int) (f: int -> 'a) =
      let type ('a, 'b) scandata = {sum: 'a, size: int, shape: 'b}
          datatype 'a tree = leaf | node of ('a, 'a tree) scandata * ('a, 'a tree) scandata
          type 'a xtree = ('a, 'a tree) scandata

          fun upsweep' () =
              let fun init (i: int) =
                      {sum = f i, size = 1, shape = leaf}
                  fun step (i: int, t: 'a xtree) =
                      (* shape of t is leaf *)
                      {sum = add (#sum t, f i), size = #size t + 1, shape = leaf}
                  fun merge (t1: 'a xtree, t2: 'a xtree) =
                      {sum = add (#sum t1, #sum t2),
                       size = #size t1 + #size t2,
                       shape = node (t1, t2)}
              in
                ForkJoin.pareduceInitStepMerge 100 (* Grains.parfor *) (i, j) init step merge
              end

          fun upsweep () =
              let fun step (i: int, t: 'a xtree) =
                      {sum = add (#sum t, f i), size = #size t + 1, shape = leaf}
                  fun merge (t1: 'a xtree, t2: 'a xtree) =
                      {sum = add (#sum t1, #sum t2),
                       size = #size t1 + #size t2,
                       shape = node (t1, t2)}
                  val base = {sum = b, size = 0, shape = leaf}
              in
                ForkJoin.pareduce 100 (* Grains.parfor *) (i, j) base step merge
              end

          fun downsweep (up: 'a xtree): 'a array =
              let val result = allocate (j - i + 1)
                  fun flat (acc: 'a) (i: int, j: int) =
                      if i >= j then
                        ()
                      else
                        (Array.update (result, i, acc);
                         flat (add (acc, f i)) (i + 1, j))
                  fun sweep (acc: 'a) (offset: int) (t: 'a xtree) =
                      case #shape t of
                          leaf => flat acc (offset, offset + #size t)
                        | node (t1, t2) =>
                          (par (fn () => sweep acc offset t1,
                                fn () => sweep (add (acc, #sum t1)) (offset + #size t1) t2)
                          ; ())
              in
                Array.update (result, j - i, #sum up);
                sweep b 0 up;
                result
              end
          val t0 = Time.now ()
          val up = upsweep ()
          val t1 = Time.now ()
          val down = downsweep up
          val t2 = Time.now ()
      in
        print ("t1 = " ^ Time.fmt 4 (Time.- (t1, t0)) ^ ", t2 = " ^ Time.fmt 4 (Time.- (t2, t1)) ^ "\n");
        down
      end*)

  fun filter (lo, hi) f g =
    let
      val n = hi - lo
      val k = Grains.block
      val m = 1 + (n - 1) div k (* number of blocks *)
      (* fun count (i, j) c =
        if i >= j then c
        else if g i then count (i + 1, j) (c + 1)
        else count (i + 1, j) c *)
      val counts = tabulate (0, m) (fn i =>
        let
          val start = lo + i * k
        in (*count (start, Int.min (start + k, hi)) 0*)
          reduce op+ 0 (start, Int.min (start + k, hi)) (fn j =>
            if g j then 1 else 0)
        end)
      val offsets = scan op+ 0 (0, m) (nth counts)
      val result = allocate (nth offsets m)
      fun filterSeq (i, j) c =
        if i >= j then ()
        else if g i then (upd result c (f i); filterSeq (i + 1, j) (c + 1))
        else filterSeq (i + 1, j) c
    in
      parfor (0, m) (fn i =>
        let val start = lo + i * k
        in filterSeq (start, Int.min (start + k, hi)) (nth offsets i)
        end);
      result
    end


  fun tabFilter (lo, hi) (f: int -> 'a option) =
    let
      val n = hi - lo
      val k = Grains.block
      val m = 1 + (n - 1) div k (* number of blocks *)
      val tmp = allocate n

      fun filterSeq (i, j, k) =
        if (i >= j) then
          k
        else
          case f i of
            NONE => filterSeq (i + 1, j, k)
          | SOME v => (A.update (tmp, k, v); filterSeq (i + 1, j, k + 1))

      val counts = tabulate (0, m) (fn i =>
        let
          val last = filterSeq
            (lo + i * k, lo + Int.min ((i + 1) * k, n), i * k)
        in
          last - i * k
        end)

      val outOff = scan op+ 0 (0, m) (fn i => A.sub (counts, i))
      val outSize = A.sub (outOff, m)

      val result = allocate outSize
    in
      parfor (0, m) (fn i =>
        let
          val soff = i * k
          val doff = A.sub (outOff, i)
          val size = A.sub (outOff, i + 1) - doff
        in
          parfor (0, size) (fn j =>
            A.update (result, doff + j, A.sub (tmp, soff + j)))
        end);
      result
    end

end
