structure MCSS =
struct
  structure CLA = CommandLineArgs

  fun mcss gen n =
    let
      val chunk_size = CLA.parseInt "chunk" 2500
      val num_chunks = (n + chunk_size - 1) div chunk_size
      val negInf = Real.negInf
      val max = Real.max
      fun __inline_always__ max3 (a, b, c) = max (a, max (b, c))

      fun kadane start stop =
        if start >= stop then (0.0, negInf, negInf, negInf)
        else
          let
            val x0 = gen start
            fun loop i (tot, pref, endHere, best) =
              if i = stop then (tot, pref, endHere, best)
              else
                let
                  val x        = gen i
                  val tot'     = tot + x
                  val pref'    = max (pref, tot')           (* best prefix is max of running totals *)
                  val endHere' = max (x, endHere + x)       (* Kadane: best suffix ending at i *)
                  val best'    = max (best, endHere')       (* best subarray overall so far *)
                in
                  loop (i+1) (tot', pref', endHere', best')
                end
          in
            loop (start+1) (x0, x0, x0, x0)
          end

      fun combine ((t1,p1,s1,b1), (t2,p2,s2,b2))  =
        let
          val t = t1 + t2
          val p = max (p1, t1 + p2)
          val s = max (s2, s1 + t2)
          val b = max3 (b1, b2, s1 + p2)
        in
          (t, p, s, b)
        end

      val zero = (0.0, negInf, negInf, negInf)

    
      

      val (_, _, _, best) =
        ForkJoin.reducem combine zero (0, num_chunks) (fn chunk_index =>
        let
          val start = chunk_index * chunk_size
          val stop  = Int.min (start + chunk_size, n)
        in
          kadane start stop
        end)
    in
      best
    end
end