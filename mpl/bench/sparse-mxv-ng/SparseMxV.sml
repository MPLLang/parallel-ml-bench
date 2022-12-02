structure SparseMxV =
struct

  fun sparseMxV (mat: (int * real) SeqNG.t SeqNG.t) (vec: real SeqNG.t) =
    let
      fun f (i,x) = (SeqNG.nth vec i) * x
      fun rowSum r =
        SeqBasisNG.reduce op+ 0.0 (0, SeqNG.length r) (fn i => f(SeqNG.nth r i))
    in
      ArraySlice.full (SeqBasisNG.tabulate (0, SeqNG.length mat) (fn i =>
        rowSum (SeqNG.nth mat i)))
    end

end
