structure Hashtable = SKHashtable

structure SeqGrid :> SU_GRID =
struct
  datatype ('a, 'b) t =
    G of
      { data: ('a * 'b list) option array
      , hash: 'a -> int
      , eq: 'a * 'a -> bool
      }

  exception GridFull

  fun strip s =
    let
      val (a, s, e) = ArraySlice.base s
    in
      a
    end

  fun initialize h eq size _ _ =
    let
      val data = Seq.tabulate (fn i => NONE) size
      fun safe_convert w = Word.toInt (Word.mod (w, Word.fromInt size))
    in
     G {data=strip data, hash = safe_convert o h, eq=eq}
    end

  (* fun bcas (arr, i) (old, new) =
    MLton.eq (old, Concurrency.casArray (arr, i) (old, new)) *)

  fun insert (G {data, hash, eq}) (k, v) =
    let
      val n = Array.length data
      val loop_ctr = 0
      fun loop i loop_ctr =
        if loop_ctr > n then raise GridFull
        else if i >= n then loop 0 (loop_ctr + 1) else
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
            let
              val new_list =
                case current of
                  NONE => [v]
                | SOME (_, l) => v::l
            in
              Array.update (data, i, SOME (k, new_list))
            end
        end
    in
      loop ((hash k) mod n) 0
    end

  fun sequentialize (G {data, hash, eq}) =
    let
      fun list_to_seq l = Seq.tabulate (fn i => List.nth (l, i)) (List.length l)
      fun translate c =
        case c of
          NONE => NONE
        | SOME (k, l) => SOME (k, list_to_seq l)
      val data' = Seq.tabulate (fn i => translate (Array.sub(data, i))) (Array.length data)
    in
      Hashtable.make_from_data {data=strip data', hash=hash, eq=eq}
    end
end
