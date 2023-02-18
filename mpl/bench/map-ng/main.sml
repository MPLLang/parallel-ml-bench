structure CLA = CommandLineArgs

fun usage () =
  let val msg = "usage: map-ng -n <SIZE> -fn-cost [light|heavy]\n"
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


fun iteratedHash k x =
  if k = 0 then x else iteratedHash (k - 1) (Util.hash x)

fun doLight () =
  let
    val input = SeqNG.tabulate (fn i => i) n
    val result = Benchmark.run "map light" (fn _ =>
      SeqNG.map (fn x => iteratedHash 10 x mod n) input)
  in
    print (Util.summarizeArraySlice 8 Int.toString result ^ "\n")
  end

fun doHeavy () =
  let
    val input = SeqNG.tabulate (fn i => i) n
    val result = Benchmark.run "map heavy" (fn _ =>
      SeqNG.map (fn x => iteratedHash 100000 x mod n) input)
  in
    print (Util.summarizeArraySlice 8 Int.toString result ^ "\n")
  end

val _ =
  case fnCost of
    "light" => doLight ()
  | "heavy" => doHeavy ()
  | _ => checkInput ()
