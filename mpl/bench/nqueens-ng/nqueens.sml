structure CLA = CommandLineArgs

type board = (int * int) list

fun threatened (i, j) [] = false
  | threatened (i, j) ((x, y) :: Q) =
      i = x orelse j = y orelse i - j = x - y orelse i + j = x + y
      orelse threatened (i, j) Q

structure FSeq = FuncSequence

fun countSol n =
  let
    fun search i b =
      if i >= n then
        1
      else
        let
          fun tryCol j =
            if threatened (i, j) b then 0 else search (i + 1) ((i, j) :: b)
        in
          SeqBasisNG.reduce op+ 0 (0, n) tryCol
        end
  in
    search 0 []
  end

(* fun countSol n = *)
(*   let *)
(*     fun search i b = *)
(*       if i >= n then *)
(*         1 *)
(*       else *)
(*         let *)
(*           fun tryCol j = *)
(*             if threatened (i, j) b then 0 else search (i + 1) ((i, j) :: b) *)
(*         in *)
(*           FSeq.reduce op+ 0 (FSeq.tabulate tryCol n) *)
(*         end *)
(*   in *)
(*     search 0 [] *)
(*   end *)

val n = CommandLineArgs.parseInt "N" 13
val _ = print ("N " ^ Int.toString n ^ "\n")

val msg =
  "counting number of " ^ Int.toString n ^ "x" ^ Int.toString n ^ " solutions"

val result = Benchmark.run msg (fn _ => countSol n)

val _ = print ("result " ^ Int.toString result ^ "\n")
