functor Mult(R: REAL) =
struct

  structure M = DenseMatColMajor
  type r = R.real
  type mat = r M.t

  fun mult (a: mat, b: mat) : mat =
    M.make {height = M.height a, width = M.width b} (fn {row, col} =>
      ForkJoin.reducem R.+ (R.fromInt 0) (0, M.width a) (fn k =>
        R.* (M.get a {row = row, col = k}, M.get b {row = k, col = col})))

end
