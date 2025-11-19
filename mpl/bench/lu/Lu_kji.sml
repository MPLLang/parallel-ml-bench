functor Lu_kji(R: REAL):
sig
  type r = R.real
  val lu_inplace: r DenseMatColMajor.t -> unit
end =
struct

  structure M = DenseMatColMajor

  type r = R.real

  fun lu_inplace (mat: r DenseMatColMajor.t) : unit =
    if M.height mat <> M.width mat then
      raise Fail "Lu_kji: non-square"
    else
      let
        val n = M.height mat
      in
        Util.for (0, n) (fn k =>
          let
            val pivot = M.get mat {col = k, row = k}
          in
            (* update left column of L by factoring out the pivot *)
            ForkJoin.parform (k + 1, n) (fn i =>
              let val elem = M.get mat {col = k, row = i}
              in M.set mat {col = k, row = i} (R./ (elem, pivot))
              end);

            (* update low-right square with the Schur complement *)
            ForkJoin.parform (k + 1, n) (fn j =>
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
          end)
      end

end
