functor CollectSort (structure K: KEY structure V: VALUE):
sig
  val collect: (K.t * V.t) Seq.t -> (K.t * V.t) Seq.t
end =
struct

  structure Key = Int

  type key = int

  fun collect kvs =
    let
      val n = Seq.length kvs

      fun key (k, v) = k
      fun value (k, v) = v

      fun key_cmp (kv1, kv2) =
        K.cmp (key kv1, key kv2)

      val t = Timer.start ()

      val sorted = Mergesort.sort key_cmp kvs

      val t = Timer.tick t "sort"

      val boundaries =
        ArraySlice.full
          (SeqBasis.filter 1000 (0, Seq.length sorted) (fn i => i) (fn i =>
             i = 0
             orelse key_cmp (Seq.nth sorted (i - 1), Seq.nth sorted i) <> EQUAL))

      val t = Timer.tick t "boundaries"

      fun make i =
        let
          val start = Seq.nth boundaries i
          val stop =
            if i + 1 = Seq.length boundaries then n
            else Seq.nth (boundaries) (i + 1)
          val k = key (Seq.nth sorted start)
          val v = ForkJoin.reducem V.combine V.zero (start, stop) (fn j =>
            value (Seq.nth sorted j))
        in
          (k, v)
        end

      val output = ForkJoin.alloc (Seq.length boundaries)
      val () = ForkJoin.parform (0, Seq.length boundaries) (fn i =>
        Array.update (output, i, make i))

      val t = Timer.tick t "make output"
    in
      ArraySlice.full output
    end

end
