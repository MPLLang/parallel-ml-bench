
structure SpanningForest =
struct
  structure G = AdjacencyGraph(Int)
  (* structure VS = G.VertexSubset *)
  structure V = G.Vertex
  structure AS = ArraySlice


  exception InvalidEdge
  exception BadForest
  type vertex = G.vertex

  fun hash_pair (i, j) =
  let
    val l = Word.fromInt (Int.min(i, j))
    val r = Word.fromInt (Int.max(i, j))
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
              else Hashtable.insert_if_absent edge_table ((cu, ci), (u, i))
            end
        in
          Seq.foreach (G.neighbors g u) (fn (i, si) => add_edge si)
        end
      val _ = ForkJoin.parfor 1000 (0, G.numVertices g) (fn i => add_edges_from i)

      val fnmapper = (fn (a, b) => case Hashtable.lookup edge_table (a, b) of
        NONE => (print("edge = (" ^ (Int.toString a) ^", "^ (Int.toString b) ^")\n"); raise InvalidEdge)
      | SOME v => v)
    in
      (AS.full (Hashtable.keys_to_arr edge_table), fnmapper)
    end

  fun contract_entangled clusters g estimated_edges =
    let
      fun center i = Seq.nth clusters i
      val (dedup_edges, edge_mapper) = inter_cluster_edges (g, center) estimated_edges
      (* val _ = print ("before contract " ^ (Int.toString (G.numVertices g)) ^ "\n") *)
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
      val old_label = ForkJoin.alloc num_taken
      val _ = Seq.foreach has_neighbor
        (fn (i, bi) => if (bi=1) then Array.update (old_label,  Seq.nth vmap i, i) else ())
      fun new_label c =
        let
          val is_taken = (Seq.nth has_neighbor c) = 1
          val num_taken_left = Seq.nth vmap c
        in
          if is_taken then num_taken_left
          else num_taken + (c - num_taken_left)
        end
      fun new_edge_mapper (a, b) = edge_mapper (Array.sub (old_label, a), Array.sub (old_label, b))
    in
      (G.fromSortedEdges new_sorted_edges, new_label, new_edge_mapper)
    end

  fun get_symm edges =
    let
      val esymm = ForkJoin.alloc (2 * (Seq.length edges))
      val _ = Seq.foreach edges (fn (i, (ui, vi)) =>
        (Array.update (esymm, 2*i, (ui, vi));
        Array.update (esymm, 2*i + 1, (vi, ui))))
    in
      AS.full (esymm)
    end

  fun sf g b =
    let
      fun sf_ g emap first =
        let
          val (n, m) = (G.numVertices g, G.numEdges g)
          val (clusters, parent) = LDD.ldd g b
          val del_edges = DelayedSeq.tabulate (fn i => (Seq.nth parent i, i)) n
          (* if parent[v] = n + 1 then v has no parent and is a cluster center *)
          val edges_ldd = DelayedSeq.toArraySeq (DelayedSeq.filter (fn (i, j) => not (i = (n+1))) del_edges)
          val edges_mapped = if first then edges_ldd else Seq.map emap edges_ldd
          val (g', center_label, emap') = contract_entangled clusters g (Real.round (b * (Real.fromInt m)))
        in
          if (G.numEdges g' = 0) then [edges_mapped]
          else
            let
              val em = if (first) then emap' else (emap o emap')
              val edges_rec = sf_ g' em false
            in
              edges_mapped::edges_rec
            end
        end
      val s = Seq.flatten (Seq.fromList (sf_ g (fn (a, b) => (a, b)) true))
    in
      s
    end

  fun check_sf g fedges =
    let
      fun count_spurious edges g =
        (* returns number of edges e : e in edges and e not in g *)
        let
          fun is_ngbr u v =
            let
              val vcmp = V.compare
              val ngbrs = (G.neighbors g u)
              val pos = BinarySearch.search vcmp ngbrs  v
            in
              vcmp (v, Seq.nth ngbrs pos) = EQUAL
            end
          val found = Seq.map (fn (u, v) => if (is_ngbr u v) then 0 else 1) edges
        in
          Seq.reduce op+ 0 found
        end

      fun isol g =
        Seq.reduce op+ 0 (Seq.tabulate (fn i => if (G.degree g i)  = 0 then 1 else 0) (G.numVertices g))
      (* create graph g' from edges in the forest *)
      val sorted_edges = Mergesort.sort (fn ((u1,v1), (u2,v2)) =>
        case V.compare (u1, u2) of
          EQUAL => V.compare (v1, v2)
        | other => other)
        (get_symm fedges)
      val g' = G.fromSortedEdges sorted_edges
      (* compare num components in g with g' ignoring isolated vertices *)
      val num_comp = (Connectivity.num_components g NONE) - (isol g)
      val num_comp' = (Connectivity.num_components g' NONE) - (isol g')
      (* also check that all edges of g' are in g *)
      val se = count_spurious sorted_edges g
    in
      if (num_comp = num_comp' andalso se = 0) then ()
      else (
        let val _ = print "spanning forest is incorrect\n";
        in raise BadForest end)
    end

  (* fun sf_debug g b =
    let
      fun sf_ g =
        let
          val (n, m) = (G.numVertices g, G.numEdges g)
          val (clusters, parent) = LDD.ldd g b
          val del_edges = DelayedSeq.tabulate (fn i => (Seq.nth parent i, i)) n
          (* if parent[v] = n + 1 then v has no parent and is a cluster center *)
          val edges_ldd = DelayedSeq.toArraySeq (DelayedSeq.filter (fn (i, j) => not (i = (n+1))) del_edges)
          (* val edges_mapped = if first then edges_ldd else Seq.map emap edges_ldd *)
          (* val _ = print "contract start\n" *)
          val (g', center_label, emap') = contract_entangled clusters g (Real.round ((Real.fromInt m)))
        in
          if (G.numEdges g' = 0) then edges_ldd
          else
            let
              val edges_rec = sf_ g'
              val _ = check_sf g' (edges_rec)
              val edges_rec_mapped = Seq.map emap' edges_rec
            in
              Seq.append (edges_rec_mapped, edges_ldd)
            end
        end
      val s = sf_ g
      val _ = check_sf g s
    in
      s
    end *)

end