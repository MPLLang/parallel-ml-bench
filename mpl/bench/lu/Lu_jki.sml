functor Lu_jki(R: REAL):
sig
  type r = R.real
  val lu_inplace: r DenseMatColMajor.t -> unit
end =
struct

  structure M = DenseMatColMajor

  type r = R.real

  fun lu_inplace (mat: r M.t) : unit =
    if M.height mat <> M.width mat then
      raise Fail "Lu_jki: non-square"
    else
      let
        val n = M.height mat
      in
        Util.for (0, n) (fn j =>
          let
            (* pull delayed Schur complement updates *)
            val () = Util.for (0, j) (fn k =>
              let
                val above = M.get mat {col = j, row = k}
              in
                ForkJoin.parform (k + 1, n) (fn i =>
                  let
                    val left = M.get mat {col = k, row = i}
                    val here = M.get mat {col = j, row = i}
                  in
                    M.set mat {col = j, row = i} (R.- (here, R.* (left, above)))
                  end)
              end)

            val pivot = M.get mat {col = j, row = j}
          in
            (* update left column of L by factoring out the pivot *)
            ForkJoin.parform (j + 1, n) (fn i =>
              let val elem = M.get mat {col = j, row = i}
              in M.set mat {col = j, row = i} (R./ (elem, pivot))
              end)
          end)
      end

end
