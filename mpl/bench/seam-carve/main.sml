structure CLA = CommandLineArgs

val filename =
  case CLA.positional () of
    [x] => x
  | _ => Util.die "missing filename"

val numSeams = CLA.parseInt "num-seams" 100
val _ = print ("num-seams " ^ Int.toString numSeams ^ "\n")

val (image, tm) = Util.getTime (fn _ => PPM.read filename)
val _ = print ("read image in " ^ Time.fmt 4 tm ^ "s\n")

fun doubleWidth () =
  let
    val h = #height image
    val w = #width image
    val newImage: PPM.image =
      {height = h, width = 2 * w, data = ArraySlice.full (ForkJoin.alloc (2*h*w))}
    val box1 = {topleft=(0,0), botright=(h,w)}
    val box2 = {topleft=(0,w), botright=(h,2*w)}
    val newImage = PPM.replace box2 (PPM.replace box1 newImage image) image
  in
    newImage
  end

val image = doubleWidth()

val carved = Benchmark.run "seam carving" (fn _ => SC.removeSeams numSeams image)

val outfile = CLA.parseString "output" ""
val _ =
  if outfile = "" then
    print ("use -output XXX to see result\n")
  else
    let
      (* val red = {red=0w255, green=0w0, blue=0w0}
      val (_, tm) = Util.getTime (fn _ =>
        PPM.write outfile (SC.paintSeam image seam red)) *)
      val (_, tm) = Util.getTime (fn _ => PPM.write outfile carved)
    in
      print ("wrote output in " ^ Time.fmt 4 tm ^ "s\n")
    end


