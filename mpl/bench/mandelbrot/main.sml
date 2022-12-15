structure CLA = CommandLineArgs
val niter = 50
val limit = 4.0

val w = CLA.parseInt "w" 16000
val _ = print ("w " ^ Int.toString w ^ "\n")

fun incr x = (x := !x + 1)

fun mark w x y =
  let
    val fw = Real.fromInt w / 2.0
    val fh = fw
    val ci = Real.fromInt y / fh - 1.0
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
  in
    loop (0.0, 0.0, 0.0) 0
  end


fun packByte w y (xlo, xhi) =
  let
    fun loop byte x =
      if x >= xhi then
        byte
      else
        let
          val byte =
            if mark w x y then
              Word.orb (Word.<< (byte, 0w1), 0wx01)
            else
              Word.<< (byte, 0w1)
        in
          loop byte (x+1)
        end
    
    val byte = loop 0w0 xlo

    val byte =
      if xhi-xlo = 8 then
        byte
      else
        Word.<< (byte, Word.fromInt (8-(xhi-xlo)))
  in
    byte
  end


fun worker w h_lo h_hi =
  let
    val numBytesPerRow = Util.ceilDiv w 8 
    val buf = ForkJoin.alloc (numBytesPerRow * (h_hi - h_lo))
  in
    Util.for (0, h_hi - h_lo) (fn i =>
      let
        val y = h_lo+i
        val offset = i * numBytesPerRow
      in
        Util.for (0, numBytesPerRow) (fn j =>
          let
            val xlo = j*8
            val xhi = Int.min (xlo + 8, w)
            val byte = packByte w y (xlo, xhi)
            val char = Char.chr (Word.toInt byte)
          in
            Array.update (buf, offset + j, char)
          end)
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


