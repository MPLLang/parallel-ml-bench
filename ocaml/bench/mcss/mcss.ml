module Mcss =
struct
  let max = Float.max

  let combine (l1,r1,b1,t1) (l2,r2,b2,t2) =
    (max l1 (t1+.l2),
     max r2 (r1+.t2),
     max (r1+.l2) (max b1 b2),
     t1+.t2)

  let id = (0.0, 0.0, 0.0, 0.0)

  let singleton v =
    let vp = max v 0.0 in
    (vp, vp, vp, v)

  let mcss (s : float Seq.t) : float =
    let _,_,b,_ =
      Seqbasis.reduce 5000 combine id (0, Seq.length s)
        (fun i -> singleton (Seq.get s i))
    in
    b

end


let n = Cla.parse_int "n" (100 * 1000 * 1000)

let gen i =
  float_of_int (Int64.to_int (Int64.sub (Util.mod64 (Util.hash64 (Int64.of_int i)) 1000L) 500L))
  /. 500.0

let input = Forkjoin.run (fun _ -> Seq.tabulate gen n)
let result = Benchmark.run "mcss" (fun _ -> Forkjoin.run (fun _ -> Mcss.mcss input))
let _ = Printf.printf "result %.3f\n" result