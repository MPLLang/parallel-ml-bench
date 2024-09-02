structure CLA = CommandLineArgs

fun sumUpTo n =
    SeqBasisNG.reduce op+ 0 (0, n) (fn i => i)

(* ==========================================================================
 * parse command-line arguments and run
 *)

val n = CLA.parseInt "N" (100 * 1000 * 1000)

val result = sumUpTo n
val _ = print ("Result = " ^ Int.toString result)


(*
parfor = do loop, spwn: par (parfor', parfor')

parfor' = do loop, spwn: par (parfor', parfor')

*)
