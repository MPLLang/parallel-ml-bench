structure CLA = CommandLineArgs

fun usage () =
  let val msg = "usage: map -n <SIZE> -fn-cost [light|heavy]\n"
  in TextIO.output (TextIO.stdErr, msg); OS.Process.exit OS.Process.failure
  end

val n = CLA.parseInt "n" (100 * 1000 * 1000)
val fnCost = CLA.parseString "fn-cost" "light"

fun checkInput () =
  if List.exists (fn x => x = fnCost) ["light", "heavy"] then
    ()
  else
    ( TextIO.output (TextIO.stdErr, "unknown -fn-cost " ^ fnCost ^ "\n")
    ; usage ()
    )

val _ = checkInput ()
val _ = print ("n " ^ Int.toString n ^ "\n")
val _ = print ("fn-cost " ^ fnCost ^ "\n")


fun modifyG grain f s =
  ForkJoin.parfor grain (0, Seq.length s) (fn i =>
    ArraySlice.update (s, i, f (i, Seq.nth s i)))

(* fun mapG grain f s =
  ArraySlice.full (SeqBasis.tabulate grain (0, Seq.length s) (f o Seq.nth s)) *)

fun iteratedHash k x =
  if k = 0 then x else iteratedHash (k - 1) (Util.hash x)

fun doLight () =
  let
    val data = Seq.tabulate (fn i => i) n
    val () = Benchmark.run "map light" (fn _ =>
      ( modifyG 5000 (fn (i, _) => i) data
      ; modifyG 5000 (fn (_, x) => x + 1) data
      ))
  in
    print (Util.summarizeArraySlice 8 Int.toString data ^ "\n")
  end

fun doHeavy () =
  let
    val data = Seq.tabulate (fn i => i) n
    val () = Benchmark.run "map heavy" (fn _ =>
      ( modifyG 5000 (fn (i, _) => i) data
      ; modifyG 1 (fn (_, x) => iteratedHash 100000 x mod n) data
      ))
  in
    print (Util.summarizeArraySlice 8 Int.toString data ^ "\n")
  end

val _ =
  case fnCost of
    "light" => doLight ()
  | "heavy" => doHeavy ()
  | _ => checkInput ()
