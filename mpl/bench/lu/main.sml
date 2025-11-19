val n = CommandLineArgs.parseInt "n" 10000

structure M = DenseMatColMajor
structure Lu_kji = Lu_kji(Real64)
structure Lu_jki = Lu_jki(Real64)
structure Lu_jik = Lu_jik(Real64)
structure Mult = Mult(Real64)

val impl = CommandLineArgs.parseString "impl" "kji"

val lulu =
  case impl of
    "kji" => Lu_kji.lu_inplace
  | "jki" => Lu_jki.lu_inplace
  | "jik" => Lu_jik.lu_inplace
  | _ => Util.die ("unknown -impl " ^ impl)

val input = M.make {height = n, width = n} (fn {row, col} =>
  Real.fromInt (Util.hash (n * col + row) mod 1000000) / 1000000.0)

val result = Benchmark.run "lu" (fn () =>
  let
    val (result, tm) = Util.getTime (fn () => M.copy input)
    val () = print ("copy:" ^ Time.fmt 4 tm ^ "s\n")
    val ((), tm) = Util.getTime (fn () => lulu result)
    val () = print ("  lu:" ^ Time.fmt 4 tm ^ "s\n")
  in
    result
  end)

val l = M.make {height = n, width = n} (fn {row, col} =>
  if row = col then 1.0
  else if col > row then 0.0
  else M.get result {row = row, col = col})

val u = M.make {height = n, width = n} (fn {row, col} =>
  if col < row then 0.0 else M.get result {row = row, col = col})

val together = Mult.mult (l, u)
val max_delta = ForkJoin.reducem Real.max Real.negInf (0, n) (fn col =>
  ForkJoin.reducem Real.max Real.negInf (0, n) (fn row =>
    M.get input {row = row, col = col} - M.get together {row = row, col = col}))
val _ = print ("max delta " ^ Real.toString max_delta ^ "\n")
