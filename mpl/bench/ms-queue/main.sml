structure CLA = CommandLineArgs
structure Grep = MkGrep(DelayedSeq)

val n = CLA.parseInt "n" 1
val bs = CLA.parseInt "bs" 1000
val nb = CLA.parseInt "nb" 100
val penq = CLA.parseReal "p-enq" 0.6
val pdeq = CLA.parseReal "p-deq" 0.4
val work = CLA.parseInt "work" 100

val _ = print ("work " ^ Int.toString work ^ "\n")
val _ = print ("bs " ^ Int.toString bs ^ "\n")
val _ = print ("p-enq " ^ Real.toString penq ^ "\n")
val _ = print ("p-deq " ^ Real.toString pdeq ^ "\n")

val _ =
  if Util.closeEnough (penq + pdeq, 1.0) then ()
  else Util.die "[ERR] probabilities (p-enq, p-deq) need to add to 1."

val file =
  case CLA.positional () of
    [file] => file
  | _ => Util.die ("[ERR] missing file")

val (input, tm) = Util.getTime (fn _ => ReadFile.contentsSeq file)
val _ = print ("read file in " ^ Time.fmt 4 tm ^ "s\n")
val ((numToks, tokRange), tm) = Util.getTime (fn _ =>
  Tokenize.tokenRanges Char.isSpace input)
val _ = print ("tokenized in " ^ Time.fmt 4 tm ^ "s\n")

(* fun genpat seed =
  let
    val x = Util.hash64 (Word64.fromInt seed)
    val len = 1 + Word64.toInt (Word64.mod (Word64.>> (x, 0w32), 0w4))

    fun cc w = Char.chr (Char.ord #"A" + Word64.toInt (Word64.mod (w, 0w26)))
    val a = cc x
    val b = cc (Word64.>> (x, 0w8))
    val c = cc (Word64.>> (x, 0w16))
    val d = cc (Word64.>> (x, 0w24))
  in
    Seq.take (Seq.fromList [a,b,c,d]) len
    (* String.implode (List.take ([a,b,c,d], len)) *)
  end *)

(* fun workload (seed: int) =
  let
    (* val pat = genpat seed *)
    val toks = Tokenize.tokens Char.isSpace input
    val i = Util.hash seed mod (Seq.length toks)
  in
    String.size (Seq.nth toks i)
    (* Seq.length (Grep.grep pat input) *)
  end *)

fun workload (data, seed: int) =
  let
    fun loop i k =
      if k >= work then i else
      let
        val i = Util.hash i mod numToks
        val (lo, hi) = tokRange i
        val tok = CharVector.tabulate (hi-lo, fn i => Seq.nth input (lo+i))
      in
        if k = (work-1) then Array.update (data, i, tok) else ();
        loop i (k+1)
      end
  in
    loop (Util.hash seed mod numToks) 0
  end

(* fun log2Int i =
  Real.ceil ((Math.log10 (Real.fromInt i)) / Math.log10 2.0) *)

(** fill it with a bunch of random keys *)
fun initialize seed =
  let
    (* val height = log2Int (n+bs) *)
    val q = MSQueue.mkQueue (~1,~1)
  in
    Util.for (0, n) (fn i =>
      let
        val x = Util.hash (seed+i) mod numToks
      in
        MSQueue.enqueue q (x,~1);
        ()
      end);
    q
  end


fun bench () =
  let
    val data = SeqBasis.tabulate 10000 (0, numToks) (fn i => "")
    val seed = 0
    val q1 = initialize seed
    val seed = seed+n
    val q2 = initialize seed
    val seed = seed+n
  in
    Util.for (0, nb) (fn i =>
      let
        val seed = seed + 3*bs
      in
        ForkJoin.parfor 1 (0, bs) (fn i =>
          let
            val k = Util.hash (seed + 3*i)
            val v = workload (data, k)
            val qp = Real.fromInt (Util.hash (seed + 3*i+1) mod 1000) / 1000.0
            val q = if qp < 0.5 then q1 else q2
            val p = Real.fromInt (Util.hash (seed + 3*i+2) mod 1000) / 1000.0
          in
            if p < penq then
              (MSQueue.enqueue q (k, v); ())
            else
              (MSQueue.dequeue q; ())
          end)
      end)
  end

val _ = Benchmark.run "msqueue list" bench



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


*)
