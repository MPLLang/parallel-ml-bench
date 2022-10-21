structure MonList : CONCURRENT_LIST =
struct

  datatype 'a pointer = NULL | S of 'a node
  withtype 'a node = 'a * 'a pointer ref

  type 'a t = {head: 'a node, tail: 'a node ref, cmp: ('a * 'a -> order)}

  fun mkList d cmp =
    let
      val head = (d, ref NULL)
    in
      {head = head, tail = ref head, cmp = cmp}
    end


  fun casVal r old new = Concurrency.cas r (old, new)

  fun node_eq cmp (n1: 'a node, n2: 'a node) =
    (cmp (#1 n1, #1 n2) = EQUAL andalso MLton.eq (#2 n1, #2 n2))

  fun opt_node_eq cmp (on1, on2) =
    case (on1, on2) of
      (NONE, NONE) => true
    | (SOME x, SOME y) => node_eq cmp (x, y)
    | _ => false

  fun lookup {head, tail, cmp} (v : 'a) =
    let
      fun lloop (v', nextp) =
        case cmp(v, v') of
          EQUAL => true
        | _ =>
          case !nextp of
            NULL => false
          | S n => lloop n
    in
      lloop head
    end

  fun insert cl (v : 'a) =
    if lookup cl v then false
    else let
      val {head, tail, cmp} = cl
      val (new_node: 'a node) = (v, ref NULL)
      fun try_insert () =
        let
          val tn = !tail
          val (tv, tnext) = tn
        in
          case !tnext of
            NULL =>
              let
                val ropt = casVal tnext NULL (S new_node)
              in
                case ropt of
                  NULL => (casVal tail tn new_node; true)
                | S x => (casVal tail tn x; try_insert() )
              end
          | S x => (casVal tail tn x; try_insert ())
        end
    in
      try_insert ()
    end

  fun size ({head, tail, cmp} : 'a t) =
    let
      fun loop h ctr =
        case !h of
          NULL => ctr
        | S n => (loop (#2 n) (ctr + 1))
    in
      loop (#2 head) 0
    end

  fun foreach ({head, tail, cmp} : 'a t) f =
    let
      fun loop h ctr =
        case !h of
          NULL => ()
        | S n => (f (ctr, #1 n); loop (#2 n) (ctr + 1))
    in
      loop (#2 head) 0
    end

end