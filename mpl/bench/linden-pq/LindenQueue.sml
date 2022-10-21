signature PRIORITY_QUEUE =
sig
  type (''a, ''b) pq
  type rand_number = int
  val create :  ''a -> ''a -> ''b -> (''a * ''a -> order) -> int -> (''a, ''b) pq
  val createCustom : int -> ''a -> ''a -> ''b -> (''a * ''a -> order) -> int -> (''a, ''b) pq
  val delMin : (''a, ''b) pq -> (''a * ''b) option
  val insert : rand_number -> (''a, ''b) pq -> (''a  * ''b) -> unit
end

fun log2Int i = Real.toInt IEEEReal.TO_POSINF ((Math.log10(Real.fromInt i)) / (Math.log10 (2.0)))

(* https://www.it.uu.se/research/publications/reports/2013-025/2013-025-nc.pdf *)

structure LindenQueue : PRIORITY_QUEUE =
struct
  datatype ('a, 'b) pointer = NULL | M of ('a, 'b) node | U of ('a, 'b) node
  withtype ('a, 'b) node = {key: 'a, next: ('a, 'b) pointer array, value: 'b ref, level: int, inserting : bool ref}

  exception BadQueue
  type ('a, 'b) pq = {head: ('a, 'b) pointer, tail: ('a, 'b) pointer, cmp: ('a * 'a -> order), numLevels: int, boundOffset: int}
  type rand_number = int

  fun initialize_arr arr f =
    let
      val len = Array.length arr
      fun init_loop idx =
        if idx = len then ()
        else (Array.update (arr, idx, f idx); init_loop (idx + 1))
    in
      init_loop 0
    end

  fun create_node (dk, dv) level ptr =
    let
      val node_arr = ForkJoin.alloc (level + 1)
      val _ = initialize_arr node_arr (fn i => ptr)
    in
      {key = dk, next = node_arr, value = ref dv, level = level, inserting = ref false}
    end

  fun createCustom boundOffset minKey maxKey dv cmp numLevels  =
    let
      val tail_node = create_node (maxKey, dv) (numLevels - 1)  NULL
      val head_node = create_node (minKey, dv) (numLevels - 1)  (U tail_node)
    in
      {head = U head_node, tail = U tail_node, cmp = cmp, numLevels = numLevels, boundOffset = boundOffset}
    end

  fun create minKey maxKey dv cmp numLevels =
    createCustom 32 minKey maxKey dv cmp numLevels

  fun unpack r =
    case r of
      NULL => raise BadQueue
    | M x => (#key x, #next x)
    | U x => (#key x, #next x)

  fun arr r = #2 (unpack r)
  fun key r = #1 (unpack r)
  fun level_node r =
    case r of
      NULL => raise BadQueue
    | M x => #level x
    | U x => #level x

  fun value_ref (r : ('a, 'b) pointer) =
    case r of
      NULL => raise BadQueue
    | M x => (#value x)
    | U x => (#value x)

  fun value r = !(value_ref r)

  fun inserting_ref r =
    case r of
      NULL => raise BadQueue
    | M x => (#inserting x)
    | U x => (#inserting x)

  fun inserting r = !(inserting_ref r)

  fun is_marked_ref r =
    case r of
       M _ => true
     | _ => false

  fun has_d_set r = is_marked_ref (Array.sub(arr r, 0))

  fun casArr arr x (old, new) = Concurrency.casArray (arr, x) (old, new) = old
  fun casBool r old new = Concurrency.cas r (old, new) = old

  fun get_unmarked_ref r =
    case r of
      M x => U x
    | _ => r

  fun get_marked_ref r =
    case r of
      U x => M x
    | _ => r

  exception Retry

  fun find_next_unmarked (rn: ('a, 'b) pointer) l =
    let
      val rnn = Array.sub (arr rn, l)
    in
      if not (is_marked_ref rnn) then (rn, rnn)
      else find_next_unmarked (get_unmarked_ref rnn) l
    end

  fun rand_level num numLevels =
    Int.mod (Util.hash (num), numLevels)
    (* let
      val hnum =  (num) + 1
      val numLevelOnes = (Real.toInt IEEEReal.TO_POSINF (Math.pow (2.0, Real.fromInt (numLevels - 1)))) - 1
      val hnum_suffix = Word.toInt ((Word.andb (Word.fromInt numLevelOnes, Word.fromInt hnum)))
      fun lsbOne i =
        let
          val x = Word.toInt (Word.andb (Word.fromInt i, Word.notb (Word.fromInt (Int.-(i, 1)))))
        in
          if x <> 0 then log2Int x
          else numLevels - 1
        end
    in
      lsbOne hnum_suffix
    end *)

  fun mark_node_pointers r =
    let
      val next_arr = arr r
      fun mark_ptrs lev =
        if lev < 0 then ()
        else
          let
            val rn = Array.sub (next_arr, lev)
          in
            if is_marked_ref rn then mark_ptrs (lev  - 1)
            else if (casArr next_arr lev (rn, get_marked_ref rn)) then mark_ptrs (lev - 1)
            else mark_ptrs lev
          end
    in
      mark_ptrs (level_node r - 1)
    end

  fun restructure (pq : (''a, ''b) pq) =
    let
      val {head, tail, numLevels, ...} = pq
      val head_arr = arr head
      fun find_next_unmarked (curr, pred) lev =
        case curr of
          NULL => raise BadQueue
        | U _ => pred
        | M _ => find_next_unmarked (Array.sub (arr curr, lev), curr) lev

      fun level lev pred =
        if lev <= 0 then ()
        else
          let
            val h = Array.sub (head_arr, lev)
            val curr = Array.sub (arr pred, lev)
          in
            case h of
              NULL => raise BadQueue
            | U _ => level (lev - 1) pred
            | M hn =>
              let
                val pred' = find_next_unmarked (curr, pred) lev
              in
                if casArr head_arr lev (h, Array.sub (arr pred', lev)) then
                  level (lev - 1) pred
                else
                  level lev pred
              end
          end
    in
      level (numLevels - 1) head
    end

  fun delMin pq =
    let
      val {head, tail, boundOffset,...} = pq
      val obs_head = Array.sub ((arr head), 0)
      fun helper x o_f new_head =
        let
          val nxt = Array.sub ((arr x), 0)
        in
          if nxt = tail then (NONE, o_f, new_head)
          else
            let
              val new_head' =
                if (inserting x) andalso (new_head = NULL) then
                  x
                else new_head
              val b = casArr (arr x) 0 (nxt, get_marked_ref nxt)
              val d = is_marked_ref nxt
            in
              if b andalso not (is_marked_ref nxt) then (SOME nxt, o_f + 1, new_head')
              else helper nxt (o_f + 1) new_head'
            end
        end
      val (x, o_f, new_head) = helper head 0 NULL
      fun detach_prefix obs_head new_head =
        if casArr (arr head) 0 (get_marked_ref obs_head, get_marked_ref new_head) then
          restructure pq
        else ()
    in
      case x of
        NONE => NONE
      | SOME x' =>
        if o_f < boundOffset then SOME (key x', value x')
        else
          (
           detach_prefix obs_head (if (new_head = NULL) then x' else new_head);
           SOME (key x', value x')
           )
    end

    fun rand_level num numLevels =
      let
        val hnum =  (num) + 1
        val numLevelOnes = (Real.toInt IEEEReal.TO_POSINF (Math.pow (2.0, Real.fromInt (numLevels - 1)))) - 1
        val hnum_suffix = Word.toInt ((Word.andb (Word.fromInt numLevelOnes, Word.fromInt hnum)))
        fun lsbOne i =
          let
            val x = Word.toInt (Word.andb (Word.fromInt i, Word.notb (Word.fromInt (Int.-(i, 1)))))
          in
            if x <> 0 then log2Int x
            else numLevels - 1
          end
      in
        lsbOne hnum_suffix
      end

    fun search (pq : (''a, ''b) pq) k =
      let
        val {head, tail, numLevels, cmp, ...} = pq
        val p = ForkJoin.alloc numLevels
        val s = ForkJoin.alloc numLevels
        fun loop (idx, pred, del) =
          if idx < 0 then del
          else
          let
            fun traverse_level (curr, pred, del) =
              let
                val lessT =
                  case cmp (key curr, k) of
                    LESS => true
                  | _ => false
                val lev_zero = (has_d_set pred andalso idx = 0)
                val del' = if lev_zero then curr else del
              in
                if lessT orelse (has_d_set curr) orelse lev_zero then
                  traverse_level (Array.sub (arr curr, idx), curr, del')
                else
                  (curr, pred, del')
              end
            val (curr, pred', del') = traverse_level (Array.sub (arr pred, idx), pred, del)
          in
            (
              Array.update (p, idx, pred');
              Array.update (s, idx, curr);
              loop (idx - 1, pred, del')
            )
          end
        val del = loop (numLevels - 1, head, NULL)
      in
        (p, s, del)
      end

    fun insert r pq (k, v) =
      let
        val level = rand_level r (#numLevels pq)
        val new_node = create_node (k, v) level NULL
        val new_ptr = U new_node
        val new_arr = arr new_ptr
        val _ = (inserting_ref new_ptr) := true
        fun insert_base_level () =
          let
            (* val _ = print "begin searching\n" *)
            val (p, s, del) = search pq k
            (* val _ = print "end searching\n" *)
            val (p0, s0) = (Array.sub (p, 0), Array.sub (s, 0))
            val _ = Array.update (new_arr, 0, s0)
            (* val _ = print ("s0 is unmarked? " ^ (Bool.toString (get_unmarked_ref s0 = s0) ^ "\n")) *)
            (* val _ = print ("s0 is NULL? " ^ (Bool.toString (NULL = s0) ^ "\n")) *)
            (* val _ = print ("p0s next is s0? " ^ (Bool.toString (Array.sub((arr p0), 0) = s0) ^ "\n")) *)
          in
            if casArr (arr p0) 0 (get_unmarked_ref s0, new_ptr) then (p, s, del)
            else insert_base_level ()
          end
        val (p, s, del) = insert_base_level ()
        (* val _ = print "base level done\n" *)

        fun insert_other_levels (p, s, del) lev =
          if lev >= level then ()
          else
            let
              val (pl, sl) = (Array.sub (p, lev), Array.sub (s, lev))
              val _ = Array.update (new_arr, lev, sl)
              val b = (has_d_set new_ptr) orelse (has_d_set sl) orelse (Array.sub (arr sl, lev) = del)
            in
              if b then ()
              else if (casArr (arr pl) lev (sl, new_ptr)) then
                insert_other_levels (p, s, del) (lev + 1)
              else
                let
                  val (p', s', del') = search pq k
                  val s0' = Array.sub (s', 0)
                in
                  if not (s0' = new_ptr) then ()
                  else
                    insert_other_levels (p', s', del') lev
                end
            end
      in
        (
          insert_other_levels (p, s, del) 1;
          (inserting_ref new_ptr) := false
        )
      end

end
