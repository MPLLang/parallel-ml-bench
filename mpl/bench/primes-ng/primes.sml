structure CLA = CommandLineArgs

(* val _ =
  MLton.Exn.setTopLevelHandler (fn exn =>
    ( print ("[" ^ Int.toString (MLton.Parallel.processorNumber ()) ^ "] unhandled exception: " ^ exnMessage exn ^ "\n")
    ; OS.Process.exit OS.Process.failure
    )) *)

(* primes: int -> int array
 * generate all primes up to (and including) n *)
fun primes n =
  if n < 2 then ForkJoin.alloc 0 else
  let
    (* all primes up to sqrt(n) *)
    val sqrtPrimes = primes (Real.floor (Math.sqrt (Real.fromInt n)))

    (* val _ = print ("allocate flags " ^ Int.toString n ^ "\n") *)
    (* allocate array of flags to mark primes. *)
    val flags = ForkJoin.alloc (n+1) : Word8.word array
    fun mark i = Array.update (flags, i, 0w0)
    fun unmark i = Array.update (flags, i, 0w1)
    fun isMarked i = Array.sub (flags, i) = 0w0

    (* val _ = print ("initial mark flags " ^ Int.toString n ^ "\n") *)
    (* initially, mark every number *)
    val _ = ForkJoinNG.parfor (0, n+1) mark

    (* val _ = print ("unmark multiples " ^ Int.toString n ^ "\n") *)
    (* unmark every multiple of every prime in sqrtPrimes *)
    val _ =
      ForkJoinNG.parfor (0, Array.length sqrtPrimes) (fn i =>
        let
          val p = Array.sub (sqrtPrimes, i)
          val numMultiples = n div p - 1
        in
          ForkJoinNG.parfor (0, numMultiples) (fn j => unmark ((j+2) * p))
        end)
      
    (* val _ = print ("filter " ^ Int.toString n ^ "\n") *)

    (* for every i in 2 <= i <= n, filter those that are still marked *)
    val result = SeqBasisNG.filter (2, n+1) (fn i => i) isMarked
  in
    (* print ("done " ^ Int.toString n ^ "\n"); *)
    result
  end

(* ==========================================================================
 * parse command-line arguments and run
 *)

val n = CLA.parseInt "N" (100 * 1000 * 1000)

val msg = "generating primes up to " ^ Int.toString n
val result = Benchmark.run msg (fn _ => primes n)

val numPrimes = Array.length result
val _ = print ("number of primes " ^ Int.toString numPrimes ^ "\n")
val _ = print ("result " ^ Util.summarizeArray 8 Int.toString result ^ "\n")


