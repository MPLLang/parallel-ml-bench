functor IntervalTree (val leaf_size: int):
sig
  type interval = int * int
  type tree

  val make_tree: interval Seq.t -> tree
  val stab_count: tree -> int -> int
end =
struct

  type k = int (* keys: left side of intervals *)
  type v = int (* values: right side of intervals *)
  type a = int (* augmented values: max right side of subtree *)

  fun aug_base (k, v) = v
  val aug_combine = Int.max
  fun aug_combine3 (a1, a2, a3) =
    aug_combine (aug_combine (a1, a2), a3)
  val aug_zero = valOf Int.minInt

  fun compare_priority (k1, k2) =
    Word64.compare
      (Util.hash64_2 (Word64.fromInt k1), Util.hash64_2 (Word64.fromInt k2))

  val compare_key = Int.compare

  datatype t =
    Empty
  | Chunk of (k * v) Seq.t
  | Node of {left: t, right: t, key: k, value: v, aug: a, size: int}

  type tree = t


  fun empty () = Empty

  fun singleton (k, v) =
    Chunk (Seq.singleton (k, v))

  fun size Empty = 0
    | size (Chunk elems) = Seq.length elems
    | size (Node {size = n, ...}) = n

  fun make_chunk elems {start, len} =
    if len = 0 then Empty else Chunk (Seq.subseq elems (start, len))


  fun expose Empty = NONE
    | expose (Node {key, value, left, right, ...}) =
        SOME (left, key, value, right)
    | expose (Chunk elems) =
        let
          val n = Seq.length elems
          val half = n div 2
          val left = make_chunk elems {start = 0, len = half}
          val right = make_chunk elems {start = half + 1, len = n - half - 1}
          val (k, v) = Seq.nth elems half
        in
          SOME (left, k, v, right)
        end


  fun get_aug_val t =
    case t of
      Empty => aug_zero
    | Chunk elems =>
        Util.loop (0, Seq.length elems) aug_zero (fn (a, j) =>
          aug_combine (a, aug_base (Seq.nth elems j)))
    | Node {aug = a, ...} => a


  fun nth t i =
    case t of
      Empty => raise Fail "IntervalTree.nth Empty"
    | Chunk elems => Seq.nth elems i
    | Node {left, right, key, value, ...} =>
        if i < size left then nth left i
        else if i = size left then (key, value)
        else nth right (i - size left - 1)


  fun make_node left (k, v) right =
    let
      val n = size left + size right + 1
      val a = aug_combine3
        (get_aug_val left, aug_base (k, v), get_aug_val right)
      val node = Node
        {left = left, right = right, key = k, value = v, size = n, aug = a}
    in
      if n <= leaf_size then Chunk (Seq.tabulate (nth node) n) else node
    end


  fun join (t1, t2) =
    if size t1 + size t2 = 0 then
      Empty
    else if size t1 + size t2 <= leaf_size then
      Chunk
        (Seq.tabulate
           (fn i => if i < size t1 then nth t1 i else nth t2 (i - size t1))
           (size t1 + size t2))
    else
      case (expose t1, expose t2) of
        (NONE, _) => t2
      | (_, NONE) => t1
      | (SOME (l1, k1, v1, r1), SOME (l2, k2, v2, r2)) =>
          case compare_priority (k1, k2) of
            GREATER => make_node l1 (k1, v1) (join (r1, t2))
          | _ => make_node (join (t1, l2)) (k2, v2) r2


  fun lookup t k =
    case t of
      Empty => NONE

    | Chunk elems =>
        let
          val n = Seq.length elems
          fun loop i =
            if i >= n then
              NONE
            else
              case compare_key (k, #1 (Seq.nth elems i)) of
                EQUAL => SOME (#2 (Seq.nth elems i))
              | GREATER => loop (i + 1)
              | LESS => NONE
        in
          loop 0
        end

    | Node {left, right, key, value, ...} =>
        case compare_key (k, key) of
          LESS => lookup left k
        | GREATER => lookup right k
        | EQUAL => SOME value


  (* ====================================================================== *)

  type interval = int * int

  fun make_tree (intervals: interval Seq.t) =
    let
      val n = Seq.length intervals
      val sorted =
        Mergesort.sort (fn ((k1, _), (k2, _)) => Int.compare (k1, k2)) intervals
      val num_chunks = Util.ceilDiv n leaf_size
    in
      SeqBasis.reduce 10 join Empty (0, num_chunks) (fn i =>
        let
          val start = i * leaf_size
          val stop = Int.min (n, start + leaf_size)
        in
          Chunk (Seq.subseq sorted (start, stop - start))
        end)
    end


  fun stab_count t x =
    case t of
      Empty => 0
    | Chunk elems =>
        Util.loop (0, Seq.length elems) 0 (fn (count, j) =>
          let val (k, v) = Seq.nth elems j
          in if x >= k andalso x < v then count + 1 else count
          end)
    | Node {left, right, key, value, ...} =>
        let
          val (left_count, right_count) =
            ForkJoin.par
              ( fn () => if get_aug_val left <= x then 0 else stab_count left x
              , fn () => if x <= key then 0 else stab_count right x
              )
          val here = if x >= key andalso x < value then 1 else 0
        in
          left_count + here + right_count
        end

end
