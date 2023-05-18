structure FindFirstNG:
sig
  val findFirstSerial: (int * int) -> (int -> bool) -> int option

  (* findFirst (start, end) predicate *)
  val findFirst: (int * int) -> (int -> bool) -> int option
end =
struct

  fun findFirstSerial (i, j) p =
    if i >= j then NONE
    else if p i then SOME i
    else findFirstSerial (i + 1, j) p

  fun optMin (a, b) =
    case (a, b) of
      (SOME x, SOME y) => (SOME (Int.min (x, y)))
    | (NONE, _) => b
    | (_, NONE) => a

  fun findFirst (lo, hi) p =
    let
      fun try (i, j) =
        SeqBasisNG.reduce optMin NONE (i, j) (fn k =>
          if p k then SOME k else NONE)

      fun loop (i, j) =
        if i >= j then
          NONE
        else
          case try (i, j) of
            NONE => loop (j, Int.min (j + 2 * (j - i), hi))
          | SOME x => SOME x
    in
      loop (lo, Int.min (lo + 4, hi))
    end

end
