signature HARRIS_LIST =
sig
  type 'a hl
  val mkList : 'a -> ('a * 'a -> order) -> 'a hl
  val delete : ''a hl -> ''a -> bool
  val insert : ''a hl -> ''a -> bool
  val find : ''a hl -> ''a -> bool
end


structure HarrisList :> HARRIS_LIST  =
struct
  datatype 'a pointer = NULL | M of 'a node | U of 'a node
  withtype 'a node = 'a * ('a pointer ref)
  exception BadList

  type 'a hl = {head: 'a pointer, tail: 'a pointer, cmp: ('a * 'a -> order)}

  fun casBool r old new =
    Concurrency.cas r (old, new) = old

  (* fun nodeEq n1 n2 =
    (cmp (#1 n1, #1 n2) = EQUAL) andalso (#2 n1 = #2 n2)

  fun pointerEq cmp p1 p2 =
    case p1 of
      NULL => p2 = NULL
    | M x1 =>
      case p2 of
        M x2 => nodeEq x1 x2
      | _ => false
    | U x1 =>
        case p2 of
          U x2 =>
        | _ => false *)

  fun mkList d cmp =
    let
      val tail_node = (d, ref NULL)
      val head_node = (d, ref (U tail_node))
    in
      {head = U head_node, tail = U tail_node, cmp = cmp}
    end

  fun is_marked_ref r =
    case r of
       M _ => true
     | _ => false

  fun get_unmarked_ref r =
    case r of
      M x => U x
    | _ => r

  fun unpack r =
    case r of
      NULL => raise BadList
    | M x => (#1 x, !(#2 (x)))
    | U x => (#1 x, !(#2 (x)))

  fun key r = #1 (unpack r)

  fun unpack_next r =
    case r of
      NULL => raise BadList
    | M x => #2 x
    | U x => #2 x

  fun isLess cmp k1 k2 =
    case cmp(k1, k2) of
      LESS => true
    | _ => false

  fun search {head, tail, cmp} k =
    let
      val isLessCmp = isLess cmp
      fun find_left_right t t_next ln lnn =
        let
          val b = not (is_marked_ref t_next)
          val (ln', lnn') = if b then (t, t_next) else (ln, lnn)
          val t' = if b then get_unmarked_ref t_next else t_next
        in
          if (t' = tail) then (ln', lnn', t')
          else
            let
              val (t_val, t_next') = unpack t'
              val b = (is_marked_ref t_next') orelse (isLessCmp t_val k)
            in
              if b then find_left_right t' t_next' ln' lnn'
              else (ln', lnn', t')
            end
        end

      fun check_found rn = not (rn <> tail andalso is_marked_ref (#2 (unpack rn)))
      fun search_loop () =
        let
          val (_, head_next) = unpack head
          val (ln, lnn, rn) = find_left_right head head_next NULL NULL
          (* val _ = print "stuck in search loop\n" *)
        in
          if (lnn = rn) andalso (check_found rn) then (ln, rn)
          else if (lnn = rn) then search_loop ()
          else if (casBool (unpack_next ln) lnn rn) andalso (check_found rn) then
            (ln, rn)
          else search_loop ()
        end
    in
      search_loop ()
    end


  fun insert ll k =
    let
      val new_node = (k, ref NULL)
      val {head, tail, cmp} = ll
      fun insert_loop () =
        let
          (* val _ = print "stuck in ins loop\n" *)
          val (ln, rn) = search ll k
          val found = (rn <> tail) andalso (key rn = k)
        in
          if found then false
          else
            (
              (#2 new_node) := rn;
              if casBool (unpack_next ln) rn (U new_node) then true
              else insert_loop ()
            )
        end
    in
      insert_loop ()
    end

  fun find ll k =
    let
      val (ln, rn) = search ll k
      val {head, tail, cmp} = ll
    in
      rn <> tail andalso (key rn = k)
    end

  fun delete ll k =
    let
      fun delete_loop () =
        let
          val (ln, rn) = search ll k
          val {head, tail, cmp} = ll
          (* val _ = print "stuck in del loop\n" *)
        in
          if rn = tail orelse (key rn <> k) then (ln, rn, NONE)
          else
            let
              val rnn_ref = unpack_next rn
              val rnn = !rnn_ref
              val b = not (is_marked_ref rnn) andalso (casBool rnn_ref rnn (get_unmarked_ref rnn))
            in
              if b then (ln, rn, SOME rnn)
              else delete_loop ()
            end
        end
      val (ln, rn, rnn_opt) = delete_loop ()
      val b = Option.isSome rnn_opt
    in
      if not b then b
      else if (casBool (unpack_next ln) rn (Option.valOf rnn_opt)) then b
      else
        let
          val _ = search ll k
        in
          b
        end
    end
end
