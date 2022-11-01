type 'a pointer = P of 'a node * int | NULL of int
and 'a node = 'a * ('a pointer Atomic.t)

type 'a queue = {
  head: 'a pointer Atomic.t;
  tail: 'a pointer Atomic.t
}

exception BadQueue

let mkQueue x =
  let dummy = (x, Atomic.make (NULL 0)) in
  let dummy_pointer = P (dummy, 0) in
  {head = Atomic.make dummy_pointer; tail = Atomic.make dummy_pointer}


let pequal p1 p2 =
  match p1, p2 with
  | (P ((_, r1), c1), P ((_, r2), c2)) -> (r1 == r2) && (c1 = c2)
  | (NULL c1, NULL c2) -> c1 = c2
  | _ -> false


let isEmpty {head; tail} =
  match Atomic.get head, Atomic.get tail with
  | (P ((_, r1), _), P ((_, r2), _)) -> r1 == r2
  | _ -> raise BadQueue


let unpack p =
  match p with
  | P (n, c) -> (n, c)
  | NULL _ -> raise BadQueue


let enqueue {tail; _} v =
  let node = (v, Atomic.make (NULL 0)) in
  let rec try_insert () =
    let tail_ptr = Atomic.get tail in
    let (tail_node, tail_count) = unpack tail_ptr in
    let (_, nextref) = tail_node in
    let next = Atomic.get nextref in
    match next with
    | NULL next_count ->
        if Atomic.compare_and_set nextref next (P (node, next_count+1))
        then (tail_ptr, tail_count)
        else try_insert ()
    | P (nodeRem, _) ->
        let _ = Atomic.compare_and_set tail tail_ptr (P (nodeRem, tail_count+1)) in
        try_insert ()
  in
  let tail_ptr, tail_count = try_insert () in
  let _ = Atomic.compare_and_set tail tail_ptr (P (node, tail_count + 1)) in
  ()


let dequeue {head; tail} =
  let rec try_remove () =
    let head_ptr = Atomic.get head in
    let tail_ptr = Atomic.get tail in
    let head_node, head_count = unpack head_ptr in
    let _, tail_count = unpack tail_ptr in
    let _, nextref = head_node in
    let next = Atomic.get nextref in
    if not (pequal (Atomic.get head) head_ptr) then try_remove () else
    if pequal head_ptr tail_ptr then
      match next with
      | NULL _ -> None
      | P (nodeRem, _) ->
          let _ = Atomic.compare_and_set tail tail_ptr (P(nodeRem, tail_count+1)) in
          try_remove ()
    else
      let node, _ = unpack next in
      let _ = Atomic.compare_and_set head head_ptr (P(node, head_count+1)) in
      let r, _ = node in
      Some r
  in
  try_remove ()
      

(*
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
*)