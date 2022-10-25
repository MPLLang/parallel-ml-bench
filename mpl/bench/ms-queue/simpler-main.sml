structure CLA = CommandLineArgs

val nq = CLA.parseInt "nq" 100000
val bs = CLA.parseInt "bs" 1000000
val work = CLA.parseInt "work" 1000
val penq = CLA.parseReal "p-enq" 0.5
val pdeq = CLA.parseReal "p-deq" 0.5

val _ = print ("nq " ^ Int.toString nq ^ "\n")
val _ = print ("bs " ^ Int.toString bs ^ "\n")
val _ = print ("work " ^ Int.toString work ^ "\n")
val _ = print ("p-enq " ^ Real.toString penq ^ "\n")
val _ = print ("p-deq " ^ Real.toString pdeq ^ "\n")

val _ =
  if Util.closeEnough (penq + pdeq, 1.0) then ()
  else Util.die "[ERR] probabilities (p-enq, p-deq) need to add to 1."

fun workload (seed: int) =
  let
    fun loop i k =
      if k = 0 then i else loop (Util.hash i) (k-1)
  in
    loop seed work
  end


fun bench () : (int * int) MSQueue.queue Seq.t =
  let
    val qs = Seq.tabulate (fn _ => MSQueue.mkQueue (~1,~1)) nq
    val seed = 0
    val grain = Int.max (1, 10000 div work)
  in
    ForkJoin.parfor grain (0, bs) (fn i =>
      let
        val k = Util.hash (seed + 3*i)
        val v = workload k
        val p = Real.fromInt (Util.hash (seed + 3*i+1) mod 1000) / 1000.0
        val qi = Util.hash (3*i+2) mod nq
        val q = Seq.nth qs qi
      in
        if p < penq then
          (MSQueue.enqueue q (k, v); ())
        else
          (MSQueue.dequeue q; MSQueue.enqueue q (k, v); ())
      end);
    qs
  end

val qs = Benchmark.run "msqueue list" bench
val data = SeqBasis.tabulate 1000 (0, Seq.length qs) (fn qi =>
  #1 (Option.getOpt (MSQueue.dequeue (Seq.nth qs qi), (~1,~1))))
val _ = print (Util.summarizeArray 10 Int.toString data ^ "\n")

