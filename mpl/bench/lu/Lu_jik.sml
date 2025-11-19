functor Lu_jik(R: REAL):
sig
  type r = R.real
  val lu_inplace: r DenseMatColMajor.t -> unit
end =
struct

  structure M = DenseMatColMajor

  type r = R.real

  fun lu_inplace (mat: r M.t) : unit =
    if M.height mat <> M.width mat then
      raise Fail "Lu_jik: non-square"
    else
      let
        val n = M.height mat
      in
        Util.for (0, n) (fn j =>
          let
            (* Update above the diagonal *)
            val () = Util.for (1, j + 1) (fn i =>
              let
                val d =
                  ForkJoin.reducem R.+ (R.fromInt 0) (0, i) (fn k =>
                    let
                      val above = M.get mat {col = j, row = k}
                      val left = M.get mat {col = k, row = i}
                    in
                      R.* (left, above)
                    end)
                
                val here = M.get mat {col=j, row=i}
              in
                M.set mat {col = j, row = i} (R.- (here, d))
              end)

            (* Update below diagonal *)
            val () = Util.for (j + 1, n) (fn i =>
              let
                val d =
                  ForkJoin.reducem R.+ (R.fromInt 0) (0, j) (fn k =>
                    let
                      val above = M.get mat {col = j, row = k}
                      val left = M.get mat {col = k, row = i}
                    in
                      R.* (left, above)
                    end);

                val elem = M.get mat {col = j, row = i}
                val pivot = M.get mat {col = j, row = j}
              in
                M.set mat {col = j, row = i} (R./ (R.- (elem, d), pivot))
              end)
          in
            ()
          end)
      end

end
