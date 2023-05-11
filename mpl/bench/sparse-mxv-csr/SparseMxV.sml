structure SparseMxV =
struct

  type mat = {data: (int * real) Seq.t, offsets: int Seq.t}

  fun sparseMxV (mat: mat) (vec: real Seq.t) =
    let
      fun f (i, x) =
        (Seq.nth vec i) * x

      val numRows = Seq.length (#offsets mat)
      fun rowStart i =
        Seq.nth (#offsets mat) i
      fun rowStop i =
        if i = numRows - 1 then Seq.length (#data mat)
        else Seq.nth (#offsets mat) (i + 1)

      fun rowSum r =
        SeqBasis.reduce 5000 op+ 0.0 (rowStart r, rowStop r) (fn i =>
          f (Seq.nth (#data mat) i))
    in
      ArraySlice.full (SeqBasis.tabulate 100 (0, numRows) rowSum)
    end

end
