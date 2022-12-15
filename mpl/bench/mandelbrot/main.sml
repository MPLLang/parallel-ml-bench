structure CLA = CommandLineArgs
val niter = 50
val limit = 4.0

val w = CLA.parseInt "w" 16000
val _ = print ("w " ^ Int.toString w ^ "\n")

fun incr x = (x := !x + 1)

fun worker w h_lo h_hi =
  let
    val buf = ForkJoin.alloc ((w div 8 + (if w mod 8 > 0 then 1 else 0)) * (h_hi - h_lo))
    val ptr = ref 0
    val fw = Real.fromInt w / 2.0
    val fh = fw
    val byte = ref 0w0
  in
    Util.for (h_lo, h_hi) (fn y =>
      let
        val ci = Real.fromInt y / fh - 1.0
      in
        (* print ("y=" ^ Int.toString y ^ "\n"); *)
        Util.for (0, w) (fn x =>
          let
            val cr = Real.fromInt x / fw - 1.5

            fun loop (zr, zi, trmti) i =
              let
                val zi = 2.0 * zr * zi + ci
                val zr = trmti + cr
                val tr = zr * zr
                val ti = zi * zi
              in
                if tr + ti > limit then
                  false
                else if i+1 = niter then
                  true
                else
                  loop (zr, zi, tr - ti) (i+1)
              end
            
            val mark = loop (0.0, 0.0, 0.0) 0
          in
            (* print ("x=" ^ Int.toString x ^ "\n"); *)
            if mark then
              byte := Word.orb (Word.<< (!byte, 0w1), 0wx01)
            else
              byte := Word.<< (!byte, 0w1);

            if x mod 8 = 7 then
              ( Array.update (buf, !ptr, Char.chr (Word.toInt (!byte)))
              ; incr ptr
              ; byte := 0w0
              )
            else ()
          end);

        let
          val rem = w mod 8
        in
          if rem <> 0 then
            ( Array.update (buf, !ptr,
                Char.chr (Word.toInt (Word.<< (!byte, Word.fromInt (8 - rem)))))
            ; incr ptr
            ; byte := 0w0
            )
          else ()
        end

      end);

    buf
  end

(* GRAIN is the target work for one worker (in terms of number of pixels);
 * this should be big enough to amortize the cost of parallelism. To match up
 * with the original code, pick the maximum "number of domains" so that each
 * domain has approximately at least GRAIN work to do (but cap this at some
 * reasonably large number...)
 *)
val GRAIN = 1000
val num_domains = Int.min (500, Int.min (w, Util.ceilDiv (w * w) GRAIN))

val rows = w div num_domains
val rem = w mod num_domains

fun work i =
  worker w (i * rows + Int.min (i, rem)) ((i+1) * rows + Int.min (i+1, rem))

val results =
  Benchmark.run "running mandelbrot" (fn _ =>
    SeqBasis.tabulate 1 (0, num_domains) work)

val outfile = CLA.parseString "output" ""

val _ =
  if outfile = "" then
    print ("use -output XXX to see result\n")
  else
    let
      val file = TextIO.openOut outfile
      fun dump1 c = TextIO.output1 (file, c)
      fun dump str = TextIO.output (file, str)
    in
      ( dump "P4\n"
      ; dump (Int.toString w ^ " " ^ Int.toString w ^ "\n")
      ; Array.app (Array.app dump1) results
      ; TextIO.closeOut file
      )
    end


