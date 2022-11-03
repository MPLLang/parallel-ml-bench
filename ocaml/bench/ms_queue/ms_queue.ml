(*
let q = Msqueue.mkQueue (-1)

let _ = Printf.printf "%b\n" (Msqueue.isEmpty q)

let _ = Msqueue.enqueue q 0

let _ = Printf.printf "%b\n" (Msqueue.isEmpty q)

let x = Option.get (Msqueue.dequeue q)
    
let _ = Printf.printf "%d\n" x
let _ = Printf.printf "%b\n" (Msqueue.isEmpty q)
*)

let nq = Cla.parse_int "nq" 100
let bs = Cla.parse_int "bs" 100000
let nb = Cla.parse_int "nb" 10
let work = Cla.parse_int "work" 1000
let penq = Cla.parse_float "p-enq" 0.5
let pdeq = Cla.parse_float "p-deq" 0.5

let _ = Printf.printf "nq %d\n" nq
let _ = Printf.printf "bs %d\n" bs
let _ = Printf.printf "work %d\n" work
let _ = Printf.printf "p-enq %.02f\n" penq
let _ = Printf.printf "p-deq %.02f\n" pdeq

let _ =
  if Float.compare (abs_float (penq +. pdeq -. 1.0)) 0.000001 < 0 then ()
  else begin
    Printf.printf "[ERR] probabilities (p-enq, p-deq) need to add to 1.\n";
    exit 1
  end

let hasher i = Int64.to_int (Util.hash64 (Int64.of_int i))

let workload seed =
  let rec loop i k =
    if k = 0 then i else loop (hasher i) (k-1)
  in
  loop seed work

let bench () =
  Forkjoin.run (fun _ ->
    let qs = Seq.tabulate (fun _ -> Msqueue.mkQueue (-1, -1)) nq in
    let seed = 0 in
    let grain = max 1 (10000 / work) in
    for j = 0 to nb-1 do
      Forkjoin.parfor grain (0, bs) (fun i ->
        let k = hasher (seed + bs*j + 3*i) in
        let v = workload k in
        let p = float_of_int (Int64.to_int (Util.mod64 (Util.hash64 (Int64.of_int (seed + bs*j + 3*i+1))) 1000L)) /. 1000.0 in
        let qi = Util.modint (hasher (seed + bs*j + 3*i+2)) nq in
        let q = Seq.get qs qi in
        if Float.compare p penq < 0 then
          begin
            Msqueue.enqueue q (k, v);
            ()
          end
        else
          begin
            let _ = Msqueue.dequeue q in
            Msqueue.enqueue q (k, v);
            ()
          end
      )
    done;
    qs
  )

let qs = Benchmark.run "msqueue list" bench

(*
val qs = Benchmark.run "msqueue list" bench
val data = SeqBasis.tabulate 1000 (0, Seq.length qs) (fn qi =>
  #1 (Option.getOpt (MSQueue.dequeue (Seq.nth qs qi), (~1,~1))))
val _ = print (Util.summarizeArray 10 Int.toString data ^ "\n")
*)