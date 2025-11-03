functor CollectHash (structure K: KEY structure V: VALUE):
sig
  val collect: (K.t * V.t) Seq.t -> (K.t * V.t) Seq.t
end =
struct

  structure T = HashTable (structure K = K structure V = V)


  fun collect kvs =
    let
      val tm = Timer.start ()

      val t = T.make {capacity = Seq.length kvs} (* very rough upper bound *)

      val tm = Timer.tick tm "initialize table"

      val _ = ForkJoin.parform (0, Seq.length kvs) (fn i =>
        T.insert_combine t (Seq.nth kvs i))

      val tm = Timer.tick tm "insertions"

      val contents = T.unsafe_view_contents t
      val results =
        ArraySlice.full
          (SeqBasis.filter 1000 (0, DelayedSeq.length contents)
             (fn i => valOf (DelayedSeq.nth contents i))
             (fn i => Option.isSome (DelayedSeq.nth contents i)))

      val tm = Timer.tick tm "filter slots"

      val sorted =
        Mergesort.sort (fn ((k1, v1), (k2, v2)) => K.cmp (k1, k2)) results

      val tm = Timer.tick tm "sorted output"
    in
      sorted
    end

end
