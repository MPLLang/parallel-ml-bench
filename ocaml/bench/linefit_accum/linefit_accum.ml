
let linefit points =
  let n = float_of_int (Seq.length points) in
  let sumPair (x1,y1) (x2,y2) = (x1 +. x2, y1 +. y2) in
  let sum f =
    Accumulate.accumulate 100000 sumPair (0.0, 0.0)
      (0, Seq.length points)
      (fun i -> f (Seq.get points i))
  in
  let square x = x *. x in
  let (xsum, ysum) = sum (fun (x,y) -> (x,y)) in
  let (xa, ya) = (xsum/.n, ysum/.n) in
  let (stt, bb) = sum (fun (x,y) -> (square(x -. xa), (x -. xa) *. y)) in
  let b = bb /. stt in
  let a = ya -. xa *. b in
  (a, b)



let n = Cla.parse_int "n" (100 * 1000 * 1000)

let gen i = (float_of_int i, float_of_int i)
let input = Forkjoin.run (fun _ -> Seq.tabulate gen n)

let a, b = Benchmark.run "linefit" (fun _ -> Forkjoin.run (fun _ -> linefit input))
let _ = Printf.printf "a %.3f\nb %.3f\n" a b