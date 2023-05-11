structure CLA = CommandLineArgs

val maxIter = CLA.parseInt "max-iter" 50
val divergeThresh = CLA.parseReal "diverge-thresh" 4.0

val _ = print ("max-iter " ^ Int.toString maxIter ^ "\n")
val _ = print ("diverge-thresh " ^ Real.toString divergeThresh ^ "\n")

(* pixels per unit of the complex plane *)
val resolution = CLA.parseInt "resolution" 5000
val _ = print ("resolution " ^ Int.toString resolution ^ "\n")

(* rectangular query region *)
val top = CLA.parseReal "top" 1.0
val bot = CLA.parseReal "bot" ~1.0
val left = CLA.parseReal "left" ~1.5
val right = CLA.parseReal "right" 0.5

val _ = print ("top " ^ Real.toString top ^ "\n")
val _ = print ("bot " ^ Real.toString bot ^ "\n")
val _ = print ("left " ^ Real.toString left ^ "\n")
val _ = print ("right " ^ Real.toString right ^ "\n")

(* derived width and height, in pixels *)
val w = Real.ceil (Real.fromInt resolution * (right - left))
val h = Real.ceil (Real.fromInt resolution * (top - bot))
val _ = print ("h " ^ Int.toString h ^ "\n")
val _ = print ("w " ^ Int.toString w ^ "\n")

val dx = (right - left) / Real.fromInt w
val dy = (top - bot) / Real.fromInt h

(* convert pixel coordinate to complex coordinate *)
fun xyToComplex (x, y) =
  let
    val r = left + (Real.fromInt x * dx)
    val i = bot + (Real.fromInt y * dy)
  in
    (r, i)
  end


fun mark x y =
  let
    val (cr, ci) = xyToComplex (x, y)

    fun loop (zr, zi, trmti) i =
      let
        val zi = 2.0 * zr * zi + ci
        val zr = trmti + cr
        val tr = zr * zr
        val ti = zi * zi
      in
        if tr + ti > divergeThresh then false
        else if i + 1 = maxIter then true
        else loop (zr, zi, tr - ti) (i + 1)
      end
  in
    loop (0.0, 0.0, 0.0) 0
  end


fun packByte y (xlo, xhi) =
  let
    fun doOne x =
      if mark x y then Word.<< (0w1, Word.fromInt (7 - (x - xlo))) else 0w0

    val byte = SeqBasisNG.reduce Word.orb 0w0 (xlo, xhi) doOne

  (* 
      fun loop byte x =
        if x >= xhi then
          byte
        else
          let
            val byte =
              if mark x y then Word.orb (Word.<< (byte, 0w1), 0wx01)
              else Word.<< (byte, 0w1)
          in
            loop byte (x + 1)
          end
  
      val byte = loop 0w0 xlo
  
      val byte =
        if xhi - xlo = 8 then byte
        else Word.<< (byte, Word.fromInt (8 - (xhi - xlo))) *)
  in
    byte
  end


fun mandelbrot () =
  let
    val numBytesPerRow = Util.ceilDiv w 8
  in
    SeqBasisNG.tabulate (0, h) (fn y =>
      SeqBasisNG.tabulate (0, numBytesPerRow) (fn b =>
        let
          val xlo = b * 8
          val xhi = Int.min (xlo + 8, w)
          val byte = packByte y (xlo, xhi)
          val char = Char.chr (Word.toInt byte)
        in
          char
        end))
  end


val results = Benchmark.run "running mandelbrot" mandelbrot

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
      ; dump (Int.toString w ^ " " ^ Int.toString h ^ "\n")
      ; Array.app (Array.app dump1) results
      ; TextIO.closeOut file
      )
    end
