structure SubsetSumNaive:
sig
  val subset_sum: int Seq.t * int -> int Seq.t option
end =
struct

  fun subset_sum (bag: int Seq.t, goal: int) =
    let
      val n = Seq.length bag

      fun loop (i, j) =
        if j = 0 then
          SOME []
        else if i >= n then
          NONE
        else if Seq.nth bag i > j then
          loop (i + 1, j)
        else
          let
            val (maybe_dont_use_it, maybe_use_it) =
              ForkJoin.par (fn () => loop (i + 1, j), fn () =>
                loop (i + 1, j - Seq.nth bag i))
          in
            if Option.isSome maybe_dont_use_it then
              maybe_dont_use_it
            else
              case maybe_use_it of
                NONE => NONE
              | SOME solution => SOME (Seq.nth bag i :: solution)
          end
    in
      case loop (0, goal) of
        SOME solution => SOME (Seq.fromList solution)
      | NONE => NONE
    end

end
