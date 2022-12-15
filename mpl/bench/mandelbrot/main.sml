structure CLA = CommandLineArgs
val niter = 50
val limit = 4.0

val w = CLA.parseInt "w" 16000
val _ = print ("w " ^ Int.toString w ^ "\n")


fun mark x y =
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


fun packByte y (xlo, xhi) =
  let
    fun loop byte x =
      if x >= xhi then
        byte
      else
        let
          val byte =
            if mark x y then
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


fun mandelbrot () =
  let
    val numBytesPerRow = Util.ceilDiv w 8
  in
    SeqBasis.tabulate 1 (0, w) (fn y =>
      SeqBasis.tabulate 1000 (0, numBytesPerRow) (fn b =>
        let
          val xlo = b*8
          val xhi = Int.min (xlo + 8, w)
          val byte = packByte y (xlo, xhi)
          val char = Char.chr (Word.toInt byte)
        in
          char
        end))
  end


val results =
  Benchmark.run "running mandelbrot" mandelbrot

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


