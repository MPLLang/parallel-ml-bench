structure CLA = CommandLineArgs

fun usage () =
  let
    val msg =
      "usage: map -n <SIZE> -fn-cost [light|heavy]\n"
  in
    TextIO.output (TextIO.stdErr, msg);
    OS.Process.exit OS.Process.failure
  end

val n = CLA.parseInt "n" (100 * 1000 * 1000)
val fnCost = CLA.parseString "fn-cost" "light"

fun checkInput () =
  if List.exists (fn x => x = fnCost) ["light", "heavy"] then ()
  else ( TextIO.output (TextIO.stdErr, "unknown -fn-cost " ^ fnCost ^ "\n")
       ; usage ()
       )

val _ = checkInput ()
val _ = print ("n " ^ Int.toString n ^ "\n")
val _ = print ("fn-cost " ^ fnCost ^ "\n")


fun mapG grain f s =
  ArraySlice.full
    (SeqBasis.tabulate grain (0, Seq.length s) (f o Seq.nth s))


fun doLight () = 
  let
    val input = SeqNG.tabulate (fn i => i) n
    val result =
      Benchmark.run "map light" (fn _ => mapG 5000 (fn x => Util.hash x mod n) input)
  in
    print (Util.summarizeArraySlice 8 Int.toString result ^ "\n")
  end

fun doHeavy () = 
  let
    val input = SeqNG.tabulate (fn i => i) n
    fun iteratedHash k x =
      if k = 0 then x else iteratedHash (k-1) (Util.hash x)
    val result =
      Benchmark.run "map heavy" (fn _ => mapG 1 (fn x => iteratedHash 100000 x mod n) input)
  in
    print (Util.summarizeArraySlice 8 Int.toString result ^ "\n")
  end

val _ =
  case fnCost of
    "light" => doLight ()
  | "heavy" => doHeavy ()
  | _ => checkInput ()