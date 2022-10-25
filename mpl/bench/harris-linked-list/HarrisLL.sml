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

fun eval_random P batch_size =
  let
    val ll = HarrisList.mkList 0 (Int.compare)

    fun rand_idx t = Int.mod (Util.hash (t), 1000000)

    fun thread i =
      let
        val rand_offset = i * i * i
        fun loop t =
          if (t = 0) then ()
          else
            let
              val randInt = rand_idx (rand_offset + t)
              fun rand_idx seed i = Int.mod (Util.hash (seed + i), 20) + 10
              val n = fib(rand_idx i t)
              val b = (randInt mod 9 <> 0)
              val _ = if b then HarrisList.insert ll randInt
                      else HarrisList.delete ll randInt
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
val _ = print ("num procs = " ^(Int.toString P) ^ "\n")
val _ = Benchmark.run "running random_eval on harris-linked-list: "
          (fn _ =>  eval_random P (CLA.parseInt "bs" 10000))

(*

structure CLA = CommandLineArgs

val r = CLA.parseInt "rounds" 0
val bs = CLA.parseInt "bs" 100000
val P = CLA.parseInt "procs" 2


val _ = print ("num procs = " ^(Int.toString P) ^ "s\n")

val (_, tm) = Util.getTime (fn _ => eval_random r P bs)
val _ = print ("batch in " ^ Time.fmt 4 tm ^ "s\n") *)

(* val ll = HarrisList.mkList 0 Int.compare
val _ = HarrisList.insert ll 2
val _ = HarrisList.insert ll 3
val b1 = HarrisList.find ll 3
val _ = HarrisList.delete ll 3
val _ = HarrisList.delete ll (~1)
val b2 = HarrisList.find ll 2
val b3 = HarrisList.find ll 3
val _ =  print ("found? " ^ (Bool.toString b1) ^ "\n")
val _ =  print ("found? " ^ (Bool.toString b2) ^ "\n")
val _ =  print ("found? " ^ (Bool.toString b3) ^ "\n") *)
