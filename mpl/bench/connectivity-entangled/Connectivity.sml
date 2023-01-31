structure Connectivity =
struct
  type 'a seq = 'a Seq.t

  structure G = AdjacencyGraph(Int)
  structure V = G.Vertex
  structure AS = ArraySlice
  structure A = Array

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
    if i1 = i2 then j1 = j2
    else false

  fun inter_cluster_edges (g, center) estimated_edges =
    let
      val edge_table = Hashtable.make ({hash= hash_pair,  eq = cmp_pair, capacity = estimated_edges})
      fun add_edges_from u =
        let
          val cu = center u
          fun add_edge i =
            let
              val ci = center i
            in
              if (cu = ci) then ()
              else Hashtable.insert_if_absent edge_table ((cu, ci), ())
            end
        in
          Seq.foreach (G.neighbors g u) (fn (i, si) => add_edge si)
        end
      val _ = ForkJoin.parfor 1000 (0, G.numVertices g) (fn i => add_edges_from i)
    in
      AS.full (Hashtable.keys_to_arr edge_table)
    end

  (* fun cmp_pair ((i1, j1), (i2, j2)) =
    if (i1 = i2) then Int.compare(j1, j2)
    else Int.compare (i1, i2)

  fun inter_cluster_edges (g, center) estimated_edges =
    let
      val edge_table = Hashtable.create hash_pair cmp_pair estimated_edges
      fun add_edges_from u =
        let
          val cu = center u
          fun add_edge i =
            let
              val ci = center i
            in
              if (cu = ci) then ()
              else Hashtable.insert edge_table (cu, ci)
            end
        in
          Seq.foreach (G.neighbors g u) (fn (i, si) => add_edge si)
        end
    in
      ForkJoin.parfor 10000 (0, G.numVertices g) (fn i => add_edges_from i);
      Hashtable.keys (edge_table)
    end *)

  fun contract_entangled clusters g estimated_edges =
    let
      fun center i = Seq.nth clusters i
      val dedup_edges = inter_cluster_edges (g, center) estimated_edges
      val dedup_sorted_edges =
        Mergesort.sort (fn ((u1,v1), (u2,v2)) =>
          case V.compare (u1, u2) of
            EQUAL => V.compare (v1, v2)
          | other => other) dedup_edges

      val (n, m) = (G.numVertices g, G.numEdges g)
      val has_neighbor = Seq.tabulate (fn i => 0) n
      val _ = Seq.foreach dedup_sorted_edges
        (fn (i, (u, v)) => if (Seq.nth has_neighbor u = 0) then AS.update (has_neighbor, u, 1) else ())
      val (vmap, num_taken) = Seq.scan Int.+ 0 has_neighbor
      (* This is still sorted because the vmap is monotonic *)
      val new_sorted_edges = Seq.map (fn (x, y) => (Seq.nth vmap x, Seq.nth vmap y)) dedup_sorted_edges
      fun new_label c =
        let
          val is_taken = (Seq.nth has_neighbor c) = 1
          val num_taken_left = Seq.nth vmap c
        in
          if is_taken then num_taken_left
          else num_taken + (c - num_taken_left)
        end
    in
      (G.fromSortedEdges new_sorted_edges, new_label)
    end

  fun printg g =
    let
      val n = G.numVertices g
      fun str_neighbors u = Seq.iterate (fn (a, b) => a ^ " " ^ (Int.toString b)) "" (G.neighbors g u)
      fun loop i =
        if i = n then ()
        else
          (print ("neighbors of vertex " ^ (Int.toString i) ^ " are " ^ (str_neighbors i) ^ "\n"); loop (i + 1))
    in
      loop 0
    end

  fun connectivity g b =
    let
      val n = G.numVertices g
      val m = G.numEdges g
      val ((clusters, _), tmldd) = Util.getTime (fn _ => LDD.ldd g b)
      val _ = print ("ldd " ^ Time.fmt 4 tmldd ^ "\n")
      val ((g', center_label), tmcon) = Util.getTime (fn _ => contract_entangled clusters g (Real.round ((Real.fromInt m))))
    in
      if (G.numEdges g') = 0 then clusters
      else
        let
          val l' = connectivity g' b
          fun center u = Seq.nth clusters u
          fun component u =
            let
              val center_g = center u
              val center_g' = center_label center_g
            in
              if (center_g' >= G.numVertices g') then center_g'
              else Seq.nth l' center_g'
            end
        in
          Seq.tabulate component n
        end
    end

  fun num_components g clusterOPT =
    let
      fun num_cc clusters =
        let
          val range = Seq.tabulate (fn i => 0) (Seq.length clusters)
          val _ = Seq.foreach clusters (fn (i, ci) => ArraySlice.update (range, ci, 1))
        in
          Seq.reduce (Int.+) 0 range
        end
    in
      case clusterOPT of
        SOME c => num_cc c
      | NONE => num_cc (connectivity g 0.3)
    end
end
