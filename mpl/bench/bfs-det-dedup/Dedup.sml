structure Dedup:
sig
  val dedup: ('k * 'k -> bool)    (* equality check *)
          -> ('k -> Word64.word)  (* first hash function *)
          -> ('k -> Word64.word)  (* second hash function *)
          -> 'k Seq.t             (* input (with duplicates) *)
          -> 'k Seq.t             (* deduplicated (not sorted!) *)
end =
struct

  structure A = Array
  structure AS = ArraySlice
  val update = Array.update
  val sub = Array.sub

  fun chunkedfor chunkSize (flo, fhi) f =
    let
      val n = fhi - flo
      val numChunks = (n-1) div chunkSize + 1
    in
      Util.for (0, numChunks) (fn i =>
        let
          val clo = flo + i*chunkSize
          val chi = if i = numChunks - 1 then fhi else flo + (i+1)*chunkSize
        in
          Util.for (clo, chi) f
        end)
    end

  fun chunkedloop chunkSize (flo, fhi) init f =
    let
      val n = fhi - flo
      val numChunks = (n-1) div chunkSize + 1
    in
      Util.loop (0, numChunks) init (fn (b, i) =>
        let
          val clo = flo + i*chunkSize
          val chi = if i = numChunks - 1 then fhi else flo + (i+1)*chunkSize
          val b' = Util.loop (clo, chi) b f
        in
          b'
        end)
    end

  datatype 'a bucketTree =
    Leaf of 'a array
  | Node of int * 'a bucketTree * 'a bucketTree

  fun count t =
    case t of
      Leaf a => A.length a
    | Node (c, _, _) => c

  fun bucketTree n (f : int -> 'a array) =
    let
      fun tree (lo, hi) =
        case hi - lo of
          0 => Leaf (ForkJoin.alloc 0)
        | 1 => Leaf (f lo)
        | n => let val mid = lo + n div 2
                  val (l, r) = ForkJoin.par (fn _ => tree (lo, mid), fn _ => tree (mid, hi))
              in Node (count l + count r, l, r)
              end
    in
      tree (0, n)
    end

  fun indexApp chunkSize (f : (int * 'a) -> unit) (t : 'a bucketTree) =
    let
      fun app offset t =
        case t of
          Leaf a => chunkedfor chunkSize (0, A.length a) (fn i => f (offset+i, sub (a, i)))
        | Node (_, l, r) =>
            (ForkJoin.par (fn _ => app offset l, fn _ => app (offset + count l) r);
            ())
    in
      app 0 t
    end

  fun compactFilter chunkSize (s : 'a option array) count =
    let
      val t = ForkJoin.alloc count
      val _ = chunkedloop chunkSize (0, A.length s) 0 (fn (ti, si) =>
        case sub (s, si) of
          NONE => ti
        | SOME x => (update (t, ti, x); ti+1))
    in
      t
    end

  fun serialHistogram eq hash s =
    let
      val n = AS.length s
      val tn = Util.boundPow2 n
      val tmask = Word64.fromInt (tn - 1)
      val t = Array.array (tn, NONE)

      fun insert k =
        let
          fun probe i =
            case sub (t, i) of
              NONE => (update (t, i, SOME k); true)
            | SOME k' =>
                if eq (k', k) then
                  false
                else if i+1 = tn then
                  probe 0
                else
                  probe (i+1)
          val h = Word64.toInt (Word64.andb (hash k, tmask))
        in
          probe h
        end

      val (sa, slo, sn) = AS.base s
      val shi = slo+sn
      val count = chunkedloop 1024 (slo, shi) 0 (fn (c, i) =>
        if insert (sub (sa, i))
        then c+1
        else c)
    in
      compactFilter 1024 t count
    end


  (* val dedup : ('k * 'k -> bool)    equality check
              -> ('k -> Word64.word)  first hash function
              -> ('k -> Word64.word)  second hash function
              -> 'k seq               input (with duplicates)
              -> 'k seq               deduplicated (not sorted!)
  *)
  fun dedup eq hash hash' keys =
    if AS.length keys = 0 then Seq.empty () else
    let
      val n = AS.length keys
      val bucketBits =
        if n < Util.pow2 27
        then (Util.log2 n - 7) div 2
        else Util.log2 n - 17
      val numBuckets = Util.pow2 (bucketBits + 1)
      val bucketMask = Word64.fromInt (numBuckets - 1)
      fun getBucket k = Word64.toInt (Word64.andb (hash k, bucketMask))
      fun ithKeyBucket i = getBucket (Seq.nth keys i)
      val (bucketed, offsets) = CountingSort.sort keys ithKeyBucket numBuckets
      fun offset i = Seq.nth offsets i
      val tree = bucketTree numBuckets (fn i =>
        let
          val bucketks = Seq.subseq bucketed (offset i, offset (i+1) - offset i)
        in
          serialHistogram eq hash' bucketks
        end)

      val result = ForkJoin.alloc (count tree)
      val _ = indexApp 1024 (fn (i, x) => update (result, i, x)) tree
    in
      AS.full result
    end

end