let n = Cla.parse_int "n" (100 * 1000 * 1000)
let doCheck = Cla.parse_flag "check"

let sparseMxV (mat: (int * float) Seq.t Seq.t) (vec: float Seq.t) =
  let f (i, x) = (Seq.get vec i) *. x in
  let rowSum r =
    Seqbasis.reduce 5000 (+.) 0.0 (0, Seq.length r) (fun i -> f(Seq.get r i))
  in
  Seq.full (Seqbasis.tabulate 100 (0, Seq.length mat) (fun i ->
    rowSum (Seq.get mat i)
  ))

let hashmod x m =
  Int64.to_int (Util.mod64 (Util.hash64 (Int64.of_int x)) (Int64.of_int m))

let rowLen = 100
let numRows = n / rowLen
let vec = Forkjoin.run (fun _ -> Seq.tabulate (fun _ -> 1.0) numRows)
let gen i j = (hashmod (i * rowLen + j) numRows, 1.0)
let mat = Forkjoin.run (fun _ -> Seq.tabulate (fun i -> Seq.tabulate (gen i) rowLen) numRows)

(* let _ = Printf.printf "here1\n" *)

let bench () = Forkjoin.run (fun _ -> sparseMxV mat vec)

let check result =
  if not doCheck then () else
  let closeEnough (a, b) = (Float.compare (abs_float (a -. b)) 0.000001 < 0) in
  let correct = Forkjoin.run (fun _ ->
    Seqbasis.reduce 1000 (fun a b -> a && b) true (0, numRows) (fun i ->
      closeEnough (Seq.get result i, float_of_int rowLen)
    ))
  in
  if correct then
    Printf.printf ("correct? yes\n")
  else
    Printf.printf ("correct? no\n")

let result = Benchmark.run "sparse-mxv" bench
(* let _ = Printf.printf "here2\n" *)
let _ = check result
(* let _ = Printf.printf "here3\n" *)

let _ =
  for i = 0 to min (numRows-1) 5 do
    Printf.printf "%.2f " (Seq.get result i)
  done;
  Printf.printf "...\n";
