
structure CList = MonList
structure Hashtable = SKHashtable

structure ParGrid :> SU_GRID  =
struct

  datatype ('a, 'b) t =
    G of
      { data: ('a * 'b CList.t) option array
      , hash: 'a -> int
      , eq: 'a * 'a -> bool
      , vcmp : 'b * 'b -> order
      , vdef : 'b
      }

  exception GridFull

  fun strip s =
    let
      val (a, s, e) = ArraySlice.base s
    in
      a
    end

  fun initialize h eq size vcmp vdef =
    let
      val data = Seq.tabulate (fn i => NONE) size
      fun safe_convert w = Word.toInt (Word.mod (w, Word.fromInt size))
    in
     G {data=strip data, hash = safe_convert o h, eq=eq, vcmp=vcmp, vdef = vdef}
    end

  fun vcas (arr, i) (old, new) = Concurrency.casArray (arr, i) (old, new)

  fun insert (G {data, hash, eq, vcmp, vdef}) (k, v) =
    let
      val n = Array.length data
      fun loop i loop_ctr =
        if (loop_ctr >= n) then raise GridFull
        else if i >=n then loop 0 (loop_ctr + 1)
        else
          let
            val current = Array.sub (data, i)
            val rightPlace =
              case current of
                NONE => true
              | SOME (k', _) => eq (k, k')
          in
            if not rightPlace then
              loop (i + 1) (loop_ctr + 1)
            else
              case current of
                NONE =>
                  let
                    val clist = CList.mkList vdef vcmp
                    val _ = vcas (data, i) (NONE, SOME (k, clist))
                    val (k', cl) = (
                      case Array.sub (data, i) of
                        NONE => raise Fail "Not supposed to happen"
                        | SOME x => x
                    )
                  in
                    if (eq (k, k')) then CList.insert cl v
                    else loop (i + 1) (loop_ctr + 1)
                  end
              | SOME (k, cl) => CList.insert cl v
          end
    in
      (loop ((hash k) mod n) 0; ())
    end

  fun sequentialize (G {data, hash, eq, ...}) =
    let
      fun translate c =
        case c of
          NONE => NONE
        | SOME (k, cl) =>
            let
              val sz = CList.size cl
              val arr = ForkJoin.alloc sz
              val _ = CList.foreach cl (fn (i, v) => Array.update (arr, i, v))
            in
              SOME (k, ArraySlice.full arr)
            end
      val data' = Seq.tabulate (fn i => translate (Array.sub (data, i))) (Array.length data)
    in
      Hashtable.make_from_data {data=strip data', hash=hash, eq=eq}
    end

end
