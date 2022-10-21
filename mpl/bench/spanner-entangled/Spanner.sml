structure Spanner =
struct
  type 'a seq = 'a Seq.t
  structure G = AdjacencyGraph(Int)
  structure V = G.Vertex
  structure AS = ArraySlice

  type vertex = G.vertex
  fun hash_pair (i, j) =
  let
    val l = Word.fromInt(Int.min(i, j))
    val r = Word.fromInt(Int.max(i, j))
    val k = Word.+(Word.<< (l, Word.fromInt 32), r)
  in
    Util.hash (Word.toInt k)
  end

  fun cmp_pair ((i1, j1), (i2, j2)) =
    if (i1 = i2) then Int.compare(j1, j2)
    else Int.compare(i1, i2)

  fun inter_cluster_edges (g, center, num_clusters) =
    let
      val estimated_edges = num_clusters * 5
      val edge_table = Hashtable.create hash_pair cmp_pair estimated_edges
      fun add_edges_from u =
        let
          val cu = center u
          fun add_edge i =
            let
              val ci = center i
              val indexi = cu*num_clusters + ci
            in
              if (cu < ci) then Hashtable.insert edge_table (cu, ci)
              else ()
            end
        in
          Seq.foreach (G.neighbors g u) (fn (i, si) => add_edge si)
        end
    in
      ForkJoin.parfor 10000 (0, G.numVertices g) (fn i => add_edges_from i);
      Hashtable.keys (edge_table)
    end

  fun spanner g k =
    let
      val n = G.numVertices g
      val b = (Math.ln (Real.fromInt n))/(Real.fromInt (2 * k))
      val ((clusters, parents), tm) = Util.getTime (fn _ => LDD.ldd g b)
      val _ = print ("ldd: " ^ Time.fmt 4 tm ^ "\n")
      fun is_center i = if i = (Seq.nth clusters i) then 1 else 0
      val num_clusters = SeqBasis.reduce 10000 (op+) 0 (0, n) is_center
      val _ = print ("number of clusters = " ^ (Int.toString (num_clusters)) ^ "\n")
      fun center i = (Seq.nth clusters i)
      fun is_self_loop i =
        let val x = (i, Seq.nth parents i)
        in #1 x = #2 x end
      val intra_edges = AS.full (SeqBasis.filter 10000 (0, n) (fn i => (i, Seq.nth parents i)) (not o is_self_loop))
      val inter_edges = inter_cluster_edges (g, center, num_clusters)
      val _ = print "deduplicated edges\n"
    in
      Seq.append (intra_edges, inter_edges)
    end
end