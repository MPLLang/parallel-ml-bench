structure CLA = CommandLineArgs

val nq = CLA.parseInt "nq" 100000
val bs = CLA.parseInt "bs" 1000000
val work = CLA.parseInt "work" 15
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

(*
fun workload (seed: int) =
  let
    fun loop i k =
      if k = 0 then i else loop (Util.hash64 i) (k-1)
  in
    Word64.toIntX (loop (Word64.fromInt seed) work)
  end
*)

fun sfib n =
  if n <= 1 then n else sfib (n-1) + sfib (n-2)

(* fun fib n =
  if n <= 20 then sfib n
  else
    let
      val (x,y) = ForkJoin.par (fn _ => fib (n-1), fn _ => fib (n-2))
    in
      x + y
    end *)

fun workload seed =
  sfib (work + seed mod 5)

fun bench () : (int * int) HarrisList.hl Seq.t =
  let
    fun mk () =
      let
        fun cmp ((a,b),(c,d)) = Int.compare (a,c)
        val q = HarrisList.mkList (~1, ~1) cmp
      in
        HarrisList.insert q (1000, ~1);
        q
      end

    val qs = Seq.tabulate (fn _ => mk ()) nq
    val seed = 0
    (* val grain = Int.max (1, 10000 div work) *)
    val grain = Int.max (1, bs div 100)
  in
    ForkJoin.parfor grain (0, bs) (fn i =>
      let
        val k = Util.hash (seed + 4*i)
        (* val v = workload k *)
        val v = workload k
        val k = k mod 1000
        val p = Real.fromInt (Util.hash (seed + 4*i+1) mod 1000) / 1000.0
        val qi = Util.hash (seed + 4*i+2) mod nq
        val q = Seq.nth qs qi
        (* val r = Util.hash (seed + 4*i+3) *)
      in
        if p < penq then
          (HarrisList.insert q (k, v); ())
        else
          (HarrisList.delete q (k, v); HarrisList.insert q (k, v); ())
      end);
    qs
  end

val qs = Benchmark.run "harris list" bench
val data = SeqBasis.tabulate 1000 (0, Seq.length qs) (fn qi =>
  if HarrisList.find (Seq.nth qs qi) (0,0) then 1 else 0)
val _ = print (Util.summarizeArray 10 Int.toString data ^ "\n")
val _ = GCStats.report ()
