
signature MS_QUEUE =
sig
  type ''a queue
  val mkQueue : ''a -> ''a queue
  val isEmpty : ''a queue -> bool
  val enqueue : ''a queue -> ''a -> unit
  val dequeue : ''a queue -> ''a option
end

structure MSQueue : MS_QUEUE =
struct
  datatype 'a pointer = P of 'a node * int | NULL of int
  withtype 'a node = 'a * ('a pointer ref)

  type 'a queue = {head: 'a pointer ref, tail: 'a pointer ref}

  exception BadQueue

  fun unpack p =
    case p of
      NULL _ => raise BadQueue
    | P (n, c) => (n, c)

  fun casBool r old new =
    Concurrency.cas r (old, new) = old

  fun isEmpty {head, tail} =
    case (!head, !tail) of
      (P x, P y) => !head = !tail
    | _ => raise BadQueue

  fun mkQueue dval =
    let
      val dummy = (dval, ref (NULL 0))
      val dummy_pointer = P (dummy, 0)
    in
      {head = ref dummy_pointer, tail = ref dummy_pointer}
    end

  fun enqueue ({head, tail}) v =
    let
      val node = (v, ref (NULL 0))
      fun try_insert () =
        let
          val tail_ptr = !tail
          val (tail_node, tail_count) = unpack tail_ptr
          val (_, nextref) = tail_node
          val next = !nextref
        in
          case next of
            NULL next_count =>
              if casBool nextref next (P (node, next_count + 1)) then (tail_ptr, tail_count)
              else try_insert ()
          | P (nodeRem, nodeRemCount) =>
            let
              val _ = casBool tail tail_ptr (P (nodeRem, tail_count + 1))
            in try_insert () end
        end
      val (tail_ptr, tail_count) = try_insert ()
      val b = casBool tail tail_ptr (P (node, tail_count + 1))
    in
      ()
    end

    fun dequeue ({head, tail}) =
      let
        fun try_remove () =
          let
            val head_ptr = !head
            val tail_ptr = !tail
            val (head_node, head_count) = unpack head_ptr
            val (tail_node, tail_count) = unpack tail_ptr
            val (_, nextref) = head_node
            val next = !nextref
          in
            if !head = head_ptr then
              if head_ptr = tail_ptr then
                case next of
                  NULL next_count => NONE
                | P (nodeRem, nodeRemCount) =>
                    let
                      val _ = casBool tail tail_ptr (P(nodeRem, tail_count + 1))
                    in try_remove () end
              else
                let
                  val (node, count) = unpack next
                  val _ = casBool head head_ptr (P (node, head_count + 1))
                in
                  SOME (#1 node)
                end
            else
              try_remove ()
          end
      in
        try_remove ()
      end
end

