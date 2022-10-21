structure CLA = CommandLineArgs

val n = CLA.parseInt "n"       1000000
val bs = CLA.parseInt "bs"     100000
val work = CLA.parseInt "work" 1000
val nq = CLA.parseInt "nq" 10
val penq = CLA.parseReal "p-enq" 0.5
val pdeq = CLA.parseReal "p-deq" 0.5

val _ = print ("work " ^ Int.toString work ^ "\n")
val _ = print ("bs " ^ Int.toString bs ^ "\n")
val _ = print ("p-enq " ^ Real.toString penq ^ "\n")
val _ = print ("p-deq " ^ Real.toString pdeq ^ "\n")

val _ =
  if Util.closeEnough (penq + pdeq, 1.0) then ()
  else Util.die "[ERR] probabilities (p-enq, p-deq) need to add to 1."

fun workload (data, seed: int) =
  let
    fun loop i k =
      if k = 0 then i else
      let
        val j = Util.hash i mod (Array.length data)
      in
        if k = 1 then Array.update (data, i, j) else ();
        loop j (k-1)
      end
    val idx = seed mod (Array.length data)
  in
    loop idx work
  end


fun bench () =
  let
    val data = SeqBasis.tabulate 10000 (0, n) (fn i => ~1)
    val qs = Seq.tabulate (fn _ => MSQueue.mkQueue (~1,~1)) nq
    val seed = 0
  in
    ForkJoin.parfor 1 (0, bs) (fn i =>
      let
        val k = Util.hash (seed + 3*i)
        val v = workload (data, k)
        val p = Real.fromInt (Util.hash (seed + 3*i+1) mod 1000) / 1000.0
        val qi = Util.hash (3*i+2) mod nq
        val q = Seq.nth qs qi
      in
        if p < penq then
          (MSQueue.enqueue q (k, v); ())
        else
          (MSQueue.dequeue q; ())
      end);
    data
  end

val data = Benchmark.run "msqueue list" bench
val _ = print (Util.summarizeArray 10 Int.toString data ^ "\n")
val _ = GCStats.report ()


(*

fun sfib n =
  if n <= 1 then n else sfib (n-1) + sfib (n-2)

fun fib n =
  if n <= 20 then sfib n
  else
    let
      val (x,y) = ForkJoin.par (fn _ => fib (n-1), fn _ => fib (n-2))
    in
      x + y
    end

fun random_eval P batch_size =
  let
    val q = MSQueue.mkQueue 0
    fun thread i =
      let
        fun loop t =
          if (t = 0) then ()
          else
            let
              fun rand_idx seed i = Int.mod (Util.hash (seed + i), 20) + 10
              val n = fib(rand_idx i t)
              val _ =
                if (t mod 2 <> 0) then (MSQueue.enqueue q (n))
                else
                let
                  val _ = MSQueue.dequeue q
                in
                  ()
                end
            in
              loop (t - 1)
            end
      in
        loop (Int.div (batch_size, P))
      end
  in
    Spawn.spawnThreads P thread
  end


structure CLA = CommandLineArgs
val P = Concurrency.numberOfProcessors

val _ = print ("num procs = " ^(Int.toString P) ^ "s\n")
val _ = Benchmark.run "running random_eval on ms-queue: "
          (fn _ =>  random_eval P (CLA.parseInt "bs" 10000))
val _ = GCStats.report ()

*)
