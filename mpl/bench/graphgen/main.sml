structure CLA = CommandLineArgs
structure G = AdjacencyGraph(Int)

fun genArrowhead n =
  let
    val toprow = Seq.tabulate (fn i => (0, i)) n
    val leftcol = Seq.tabulate (fn i => (i, 0)) n
    val diagonal = Seq.tabulate (fn i => (i, i)) n

    val allEdges =
      Seq.flatten (Seq.fromList
        [ toprow
        , Seq.drop leftcol 1  (* don't repeat (0,0) *)
        , Seq.drop diagonal 1 (* don't repeat (0,0) *)
        ])
    
    val sorted =
      Mergesort.sort (fn ((u1,v1), (u2,v2)) =>
        case Int.compare (u1, u2) of
          EQUAL => Int.compare (v1, v2)
        | other => other) allEdges
  in
    G.fromSortedEdges sorted
  end

val graphType = CLA.parseString "type" "arrowhead"
val n = CLA.parseInt "n" (1000 * 1000)
val outfile = CLA.parseString "outfile" ""

val gen =
  case graphType of
    "arrowhead" => (fn _ => genArrowhead n)
  | _ => Util.die ("[ERR] unknown -type " ^ graphType)

val graph = Benchmark.run graphType gen

val _ =
  if outfile = "" then () else
  let
    val (_, tm) = Util.getTime (fn _ => G.writeAsBinaryFormat graph outfile)
  in
    print ("wrote graph (binary format) to " ^ outfile ^ " in " ^ Time.fmt 4 tm ^ "s\n")
  end