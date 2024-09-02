structure CLA = CommandLineArgs
structure Seq = SeqNG
structure DS = DelayedSeqNG
structure G = AdjacencyGraph(Int)

structure M = SparseMxV

val infile = CLA.parseString "infile" ""

val (mat, vec, check) =
  if infile <> "" then
    let
      val (graph, tm) = Util.getTime (fn _ => G.parseFile infile)
      val _ = print ("loaded " ^ infile ^ " in " ^ Time.fmt 4 tm ^ "s\n")
      val _ = print
        ("num vertices: " ^ Int.toString (G.numVertices graph) ^ "\n")
      val _ = print ("num edges: " ^ Int.toString (G.numEdges graph) ^ "\n")

      val mat =
        Seq.tabulate (fn i => Seq.map (fn j => (j, 1.0)) (G.neighbors graph i))
          (G.numVertices graph)

      val offsets = SeqBasis.scan 1000 op+ 0 (0, Seq.length mat)
        (Seq.length o Seq.nth mat)
      val data = Seq.flatten mat
      val mat =
        { data = data
        , offsets = Seq.take (ArraySlice.full offsets) (Seq.length mat)
        }

      val vec = Seq.tabulate (fn i => 1.0) (G.numVertices graph)

      fun check result =
        print "--check: skipping (not yet implemented for this input)\n"
    in
      (mat, vec, check)
    end
  else
    let
      val n = CLA.parseInt "n" (1000 * 1000 * 100)
      val rowLen = CLA.parseInt "row-len" 100
      val numRows = n div rowLen

      val _ = print ("n " ^ Int.toString n ^ "\n")
      val _ = print ("row-len " ^ Int.toString rowLen ^ "\n")
      val _ = print ("(num rows: " ^ Int.toString numRows ^ ")\n")

      val vec = Seq.tabulate (fn i => 1.0) numRows
      fun gen i j =
        ((Util.hash (i * rowLen + j) mod numRows), 1.0)
      val data =
        Seq.tabulate (fn i => (Util.hash i mod numRows, 1.0)) (numRows * rowLen)
      val offsets = Seq.tabulate (fn i => i * rowLen) numRows
      val mat = {data = data, offsets = offsets}

      fun check result =
        let
          fun closeEnough (a, b) =
            Real.< (Real.abs (a - b), 0.000001)
          val correct = DS.reduce (fn (a, b) => a andalso b) true
            (DS.tabulate
               (fn i => closeEnough (Seq.nth result i, Real.fromInt rowLen))
               numRows)
        in
          if correct then print ("correct? yes\n") else print ("correct? no\n")
        end
    in
      (mat, vec, check)
    end


val doCheck = CLA.parseFlag "check"

fun task () = M.sparseMxV mat vec

val result = Benchmark.run "sparse-mxv" task
val _ = if not doCheck then () else check result
