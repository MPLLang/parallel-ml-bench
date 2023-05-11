structure SparseMxV =
struct

  type mat = {data: (int * real) SeqNG.t, offsets: int SeqNG.t}

  fun sparseMxV (mat: mat) (vec: real SeqNG.t) =
    let
      fun f (i, x) =
        (SeqNG.nth vec i) * x

      val numRows = SeqNG.length (#offsets mat)
      fun rowStart i =
        SeqNG.nth (#offsets mat) i
      fun rowStop i =
        if i = numRows - 1 then SeqNG.length (#data mat)
        else SeqNG.nth (#offsets mat) (i + 1)

      fun rowSum r =
        SeqBasisNG.reduce op+ 0.0 (rowStart r, rowStop r) (fn i =>
          f (SeqNG.nth (#data mat) i))
    in
      ArraySlice.full (SeqBasisNG.tabulate (0, numRows) rowSum)
    end

end
