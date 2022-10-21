structure Hashtable = SKHashtable

functor Net (structure SMatrix : SU; structure Grid : SU_GRID; structure OptC : OPT_CIRCUIT) =
struct

  exception WrongOpt

  structure GateSet =
  struct

    type red = {eq : (SMatrix.t * int Seq.t) Seq.t, max_len : int, eqdagger : (SMatrix.t * int Seq.t) Seq.t ref}

    type t = {gates: SMatrix.t Seq.t, labels: string Seq.t, order: int Seq.t, inverses: int Seq.t, size: int, optc: OptC.t, optbrute: red}

    fun gates (gs: t) = (#gates gs)
    fun size (gs: t) = Seq.length (#gates gs)
    fun gatem (gs: t) i = Seq.nth (#gates gs) i
    fun order (gs : t) i = Seq.nth (#order gs) i
    fun inverse (gs: t) i = Seq.nth (#inverses gs) i
    fun perm_to_mat (gs : t) perm = Seq.reduce SMatrix.multiply (SMatrix.id()) (Seq.map (gatem gs) perm)
    fun perm_to_mat_gates gates perm = Seq.reduce SMatrix.multiply (SMatrix.id()) (Seq.map (Seq.nth gates) perm)
    fun inverse_ord (gs: t) i =
     if (order gs i = 2) then i
     else inverse gs i

    fun id_idx (gs : t) = 0

    fun label (gs: t) idx = Seq.nth (#labels gs) idx

    fun perm_to_string (gs: t) perm =
      if (Seq.length perm = 0) then "I"
      else Seq.reduce (fn (a, b) => a ^ " " ^ b) "" (Seq.map (label gs) perm)

    fun invert_perm (gs: t) perm =
      Seq.tabulate (fn i => inverse_ord gs (Seq.nth perm (Seq.length perm - 1 - i))) (Seq.length perm)

    fun append_perm (gs: t) p1 p2 = Seq.append (p1, p2)

    fun find_approx (gs : t) (m, p) slop =
      let
        val {eq = mats, max_len = mlen, ...} = #optbrute gs
        val slop' = slop/3.0
        fun within_slop m (m', _) = abs (SMatrix.proj_trace_dist (m, m') - slop') < slop'
        fun find_best (m, p) =
          Seq.reduce (fn ((ma, pa), (mb, pb)) => if (Seq.length pa < Seq.length pb) then (ma, pa) else (mb, pb)) (m, p)
          (Seq.filter (within_slop m) mats)
        val (m', p') = find_best (m, p)
        val _ = if (SMatrix.equiv (slop) (m, m')) then () else
        (print (SMatrix.str m); print (SMatrix.str m'); print "problem in find_approx\n"; raise WrongOpt)

       fun printSeq s = print ((Seq.reduce (fn (a, b) => a ^ " " ^ b) "" (Seq.map (label gs) s)) ^ "\n")
      in
        if (Seq.length p = Seq.length p') then NONE
        else (
          (* (printSeq p); print (SMatrix.str m); (printSeq p');print (SMatrix.str m');  *)
          SOME (m', p', Seq.length p - Seq.length p'))
      end


    fun tabulate f n = ArraySlice.full (SeqBasis.tabulate 20 (0, n) f)
    fun approx_slices (gs : t) (m, p) slop =
      let
        val pz = Seq.length p
        (* val msz = Int.max (3 * (Int.div (Seq.length p, 4)), #max_len (#optbrute gs)) *)
        val start_sz =  #max_len (#optbrute gs)
        val end_sz = if pz > start_sz then pz else start_sz
        (* val num_slices = Seq.tabulate (fn ssz => ) (end_sz - start_sz + 1) *)


        fun check_slice idx msz =
          let
            val ssz = Int.min (msz, pz - idx)
            val sl =  Seq.subseq p (idx, ssz)
          in
            case find_approx gs (perm_to_mat gs sl, sl) slop of
              NONE => NONE
            | SOME b => SOME (idx, b)
          end

        val num_slices = (end_sz - start_sz + 1) * (Seq.length p)
        val _ = print ("checking " ^ (Int.toString (Seq.length p) ^ " slices\n"))
        val new_reps = tabulate (fn i => check_slice (i mod (Seq.length p)) (start_sz + i div (Seq.length p))) num_slices
        val best_sub = Seq.reduce
        (fn (a, b) =>
          case (a, b) of
            (_, NONE) => a
          | (NONE, _) => b
          | (SOME (_, (_, _, opa)), SOME (_, (_, _, opb))) => if opa > opb then a else b)
          NONE
          new_reps
      in
        case best_sub of
          NONE => NONE
        | SOME (i, (m', p', red)) =>
          let
            val sub_size = Seq.length p'
            fun g n =
              if n < i then Seq.nth p n
              else if (n - i < sub_size) then Seq.nth p' (n - i)
              else Seq.nth p (n + red)
            val new_rep = Seq.tabulate g (pz - red)
            val _ = print ("approx red = " ^ (Int.toString red)  ^ " slop used = " ^ (Real.toString (SMatrix.proj_trace_dist (m, perm_to_mat gs new_rep)))
              ^ " allowed slop = " ^ (Real.toString slop) ^ "\n")
            (* val _ = print ("best slice size = " ^ (Int.toString (sub_size + red))) *)
          in
            SOME (new_rep)
          end

      end

    fun check_prefix_id (gs : t) perm =
      let
        val mats = Seq.map (gatem gs) perm
        val (mat_val, fin) = Seq.scan SMatrix.multiply (SMatrix.id ()) mats
        fun check_id m = SMatrix.equiv 1E~12 (SMatrix.id(), m)
        fun find_longest_id idx curr =
          if (idx >= Seq.length mat_val) then curr
          else if check_id (Seq.nth mat_val idx) then
            find_longest_id (idx + 1) idx
          else find_longest_id (idx + 1) curr
        val x = if (check_id fin) then Seq.length perm
                else find_longest_id 0 0
      in
        if x = 0 then NONE
        else SOME (Seq.drop perm x)
      end

    val useopt = CommandLineArgs.parseBool "useopt" false
    val useopt2 = CommandLineArgs.parseBool "useopt2" false
    (* could add optimizations here *)
    (* take t from p1 and t' from p2 such that t + t' <= sz *)
    fun append_perm_opt (gs : t) slop p1 p2  =
      if (not useopt2) then append_perm gs p1 p2
      else let
        val optc = (#optc gs)
        val sz = 52
        fun append3 (a, b, c) =
          let
            val (sa, sb, sc) = (Seq.length a, Seq.length b, Seq.length c)
          in
            Seq.tabulate
            (fn i =>
              if i < sa then Seq.nth a i
              else if i < sa + sb then Seq.nth b (i - sa)
              else Seq.nth c (i - sa - sb))
            (sa + sb + sc)
          end
        fun printSeq s = print ((Seq.reduce (fn (a, b) => a ^ " " ^ b) "" (Seq.map (label gs) s)) ^ "\n")

        (* start with a default credit of 3 --- max number of times we can lookup without size reduction *)
        val ic = 3
        fun opt_loop p1 p2 seam credits =
          if credits = 0 orelse sz < 1 then append3 (p1, seam, p2)
          else if (Seq.length p1 = 0) orelse (Seq.length p2 = 0) then append3 (p1, seam, p2)
          else let
            val t1 = Int.min (sz, Seq.length p1)
            val t2 = Int.min (sz, Seq.length p2)
            val (s1, s2) =  (Seq.drop p1 ((Seq.length p1) - t1), Seq.take p2 t2)
            val s = append3 (s1, seam, s2)
            (* val _ = print "feeding to opt \t" *)
            (* val _ = printSeq s *)
            val new_rep = OptC.lookup optc (Seq.length s, Seq.nth s)
            val new_rep' = approx_slices gs (perm_to_mat gs s, s) slop
            (* val _ = print ("slop = " ^ (Real.toString slop) ^ "\n") *)
            val nr =
              case (new_rep, new_rep') of
                (NONE, _) => new_rep'
              | (_, NONE) => new_rep
              | (SOME s, SOME s') =>
                if (Seq.length s >= Seq.length s') then (print "approx wins\n"; SOME s') else SOME s
            (* val nr' = check_prefix_id gs s
            val new_rep =
              case (nr', new_rep) of
                (NONE, _) => new_rep
              | (_, NONE) => nr'
              | (SOME s, SOME s') =>
                if (Seq.length s > Seq.length s') then SOME s'
                else SOME s *)
          in
            case nr of
              NONE => append3 (p1, seam, p2)
            | SOME s =>
              let
                val ssize = Seq.length s
                (* val _ = print "got from opt \t" *)
                (* val _ = printSeq s *)
                fun count_common (a, aidx) (b, bidx) inc cnt lim =
                  if cnt >= lim then cnt
                  else if (Seq.nth a aidx = Seq.nth b bidx) then
                    count_common (a, inc aidx) (b, inc bidx) inc (cnt + 1) lim
                  else cnt
                val t1' = count_common (p1, (Seq.length p1) - t1) (s, 0) (fn i => i + 1) 0 (Int.min (t1, ssize))
                val rem_size = ssize - t1'
                val t2' = count_common (p2, t2 - 1) (s, ssize - 1) (fn i => i - 1) 0 (Int.min (t2, ssize - t1'))

                val p1' =  (Seq.take p1 ((Seq.length p1) - t1 + t1'))
                val p2' = (Seq.drop p2 (t2 - t2'))
                val seam' = (Seq.subseq s (t1', ssize - t2' - t1'))
                val len_reduced = ((t1 - t1') + (t2 - t2') + ((Seq.length seam) - (Seq.length seam'))) > 0

                fun verify (p1, s, p2) (p1', s', p2') =
                  let
                    val ma = perm_to_mat gs (append3 (p1, s, p2))
                    val mb = perm_to_mat gs (append3 (p1', s', p2'))
                  in
                    if (SMatrix.equiv slop (ma, mb)) then () else
                      (print "inverif\n"; print (Real.toString (SMatrix.proj_trace_dist (ma, mb)) ^ "\n") ; print (SMatrix.str ma); print (SMatrix.str mb); raise WrongOpt)
                  end
                (* val _ = verify (p1, seam, p2) (p1', seam', p2') *)
              in
                opt_loop p1' p2' seam' (if len_reduced then ic else (credits - 1))
              end
          end
        val s = opt_loop p1 p2 (Seq.empty()) ic
        val s' = append_perm gs p1 p2
        val red = (Seq.length p1) + (Seq.length p2) - (Seq.length s)
        fun verify s s' =
          let
            val m = perm_to_mat gs s
            val m' = perm_to_mat gs s'
          in
            if (SMatrix.equiv (2.0 * slop) (m, m')) then ()
            else ((printSeq s); (printSeq s'); raise WrongOpt)
          end
        (* val _ = verify s s' *)
      in
        (
          (* print ("red = " ^(Int.toString red)^ "\n\n");  *)
        s)
      end


    fun perm_compare (p1, p2) =
      let
        val n1 = Seq.length p1
        val n2 = Seq.length p2
      in
        case Int.compare (n1, n2) of
          EQUAL =>
            let
              fun loop i =
                if (i >= n1) then EQUAL
                else
                  let
                    val (i1, i2) = (Seq.nth p1 i, Seq.nth p2 i)
                  in
                    case Int.compare (i1, i2) of
                      EQUAL => loop (i + 1)
                    | lg => lg
                  end
            in
              loop 0
            end
        | lg => lg
      end

    fun perm_new (gs: t) (perm_list, m) =
      let
        fun list_nth l idx = List.nth (l, idx)
        fun check_prefix () =
          if (List.length perm_list < 1) then true
          else
              let
                val l = List.length perm_list
                val head = list_nth perm_list 0
                fun inverse_check () =
                  if l < 2 then true
                  else (list_nth perm_list 1 <> inverse gs head)
                val ord = Seq.nth (#order gs) head
                fun order_check2 ord =
                  if ord <> 2 then true
                  else (inverse gs head >= head)

                fun order_check ord =
                  (* assume l >= ord *)
                  if ord = 0 then false
                  else if (list_nth perm_list (ord - 1) <> head) then true
                  else order_check (ord - 1)
              in
                inverse_check () andalso (l < ord orelse order_check ord) andalso (order_check2 ord)
              end
        val opt_perm = if useopt then OptC.lookup (#optc gs) (List.length perm_list, list_nth perm_list) else NONE
      in
        case opt_perm of
          SOME x => false
        | NONE => check_prefix ()
      end
  end

  type knot = {perm: int Seq.t, M: SMatrix.t}
  type store = (SMatrix.coord, knot Seq.t) Hashtable.hashtable
  type net = {basis : GateSet.t, tile_width: real, grid : store}

  fun knot_to_string gs kn = (GateSet.perm_to_string gs (#perm kn))
  fun net_to_string (n : net) =
  let
    fun list_to_string (sep : string) (f : 'a -> string) ([] : 'a list) : string = ".\n"
      | list_to_string sep f (x::xs) = (f x) ^ sep ^ (list_to_string sep f xs)

    fun cknots_to_string gs (c, kn_seq) = list_to_string ", " (knot_to_string gs) (Seq.toList kn_seq)
    fun store_to_string gs ht = list_to_string "\n" (cknots_to_string gs) (Hashtable.to_list ht)
  in
    (store_to_string (#basis n)) (#grid n)
  end

  fun knot_inverse gs k = {perm = GateSet.invert_perm gs (#perm k), M = SMatrix.dagger (#M k)}
  val id_knot = {perm = Seq.empty (), M = SMatrix.id ()}

  fun knot_cmp (k1, k2) =
    let
      val (p1, m1) = (#perm k1, #M k1)
      val (p2, m2) = (#perm k2, #M k2)
    in
      if SMatrix.equiv 1E~12 (m1, m2) then EQUAL
      else if (Seq.length p1 = Seq.length p2) then
        case SMatrix.compare (m1, m2) of
          EQUAL => GateSet.perm_compare (p1, p2)
        | lg => lg
      else Int.compare (Seq.length p1, Seq.length p2)
    end

  (* TODO: gen grid_size from num_intervals *)
  val grid_size = CommandLineArgs.parseInt "gridsize" 100000

  exception BadUnitary
  fun check_gate_set gs =
    let
      fun is1 (a, b) = (abs (a - 1.0) < 1E~12) andalso (abs (b) < 1E~12)

      fun gate i = GateSet.gatem gs i
      fun check_gate i =
        SMatrix.equiv 1E~12 (SMatrix.id(), SMatrix.multiply (gate i, SMatrix.dagger (gate i)))
        andalso
        SMatrix.equiv 1E~12 (SMatrix.dagger (gate i), gate (GateSet.inverse gs i))
        andalso
        is1 (SMatrix.det (gate i))
      val s = Seq.tabulate check_gate (GateSet.size gs)
      val all_ok = Seq.reduce (fn (a, b) => a andalso b) true s
    in
      if all_ok then () else raise BadUnitary
    end

  fun net_stats (net : net) =
    let
      fun is_equiv (kn1 : knot, kn2 : knot) =
        if (SMatrix.equiv 1E~12 (#M kn1, #M kn2)) then 1
        (* print ((knot_to_string (#basis net) kn1) ^ " == " ^ (knot_to_string (#basis net) kn2) ^ "\n"); *)
        else 0
      val num_equiv = ForkJoin.alloc (Hashtable.size (#grid net))
      val sizes = ForkJoin.alloc (Hashtable.size (#grid net))
      fun f_point (gn, ms) =
        case ms of
          NONE =>
            (Array.update (num_equiv, gn, 0);
            Array.update (sizes, gn, 0))
        | SOME (_, ms) =>
        let
          val n = Seq.length ms
          (* i, j maps to i * n + j *)
          fun mat_idx k = (k div n, k mod n)
          val eq_seq = Seq.tabulate (fn k =>
            let
              val (i, j) = mat_idx k
            in
              is_equiv (Seq.nth ms i, Seq.nth ms j)
            end) (n * n)
          val num_eq = ((Seq.reduce op+ 0 eq_seq) - n) div 2
        in
          (Array.update (num_equiv, gn, num_eq);
          Array.update (sizes, gn, n))
        end
      val _ = Hashtable.foreach (#grid net) f_point
      val total_redundant = Seq.reduce op+ 0 (ArraySlice.full num_equiv)
      val total_size = Seq.reduce op+ 0 (ArraySlice.full sizes)
    in
      (print ("total red = " ^ (Int.toString total_redundant) ^ " total size = " ^ (Int.toString total_size) ^ "\n"))
    end

  fun gforeach gran s f = ForkJoin.parfor gran (0, Seq.length s) (fn i => f (i, Seq.nth s i))

  fun create_net_from_perms ((gs, tile_width, repseq) : GateSet.t * real * int Seq.t Seq.t) : net =
    let
      val grid = Grid.initialize SMatrix.hash SMatrix.coord_eq grid_size knot_cmp id_knot
      fun add_to_net (idx : int, (perm : int Seq.t)) =
        let
          val kn = {perm = perm, M = GateSet.perm_to_mat gs perm}
          val num_intervals = Real.ceil (2.0/tile_width)
          fun add_to_coord (_, c : SMatrix.coord) = (Grid.insert grid (c, kn); ())
        in
          Seq.foreach (SMatrix.all_coordinates (#M kn) num_intervals) add_to_coord
        end
      val _ = gforeach 1000 repseq add_to_net
      val net = {basis = gs, tile_width = tile_width, grid = Grid.sequentialize grid}
    in
      net
    end

  fun generate_net ((gs, tile_width) : GateSet.t * real) (max_length : int) : net =
    let
      val _ = check_gate_set gs
      val gatesi = Seq.tabulate (fn i => i) (GateSet.size gs)
      val grid = Grid.initialize SMatrix.hash SMatrix.coord_eq grid_size knot_cmp id_knot

      fun add_to_net (idx : int, ((perm, m) : int list * SMatrix.t)) =
        let
          val kn = {perm = Seq.fromList perm, M = m}
          val num_intervals = Real.ceil (2.0/tile_width)
          fun add_to_coord (_, c : SMatrix.coord) = (Grid.insert grid (c, kn); ())
        in
          (* add_to_coord (0, SMatrix.coordinate m num_intervals) *)
          Seq.foreach (SMatrix.all_coordinates m num_intervals) add_to_coord
        end

      val perm_new = GateSet.perm_new gs
      fun gen_perm n =
        if n = 0 then
          let
            val s = Seq.tabulate (fn i => ([], SMatrix.id())) 1
          in
            (Seq.foreach s add_to_net; s)
          end
        else
          let
            val base_perms = gen_perm (n - 1)
            fun prepend_gate_to_perm g (perm, m) = (g :: perm, SMatrix.multiply (GateSet.gatem gs g, m))

            val (pnum, gnum) = (Seq.length base_perms, GateSet.size gs)
            fun perm_seq i =
              let
                fun perm k = Seq.nth base_perms (k div gnum)
                fun gate k = Int.mod (k, gnum)
              in
                prepend_gate_to_perm (gate i) (perm i)
              end

            val useful_perms = ArraySlice.full (SeqBasis.filter 500 (0, pnum*gnum) perm_seq (perm_new o perm_seq))
            val _ = gforeach 100 useful_perms add_to_net
          in
            useful_perms
          end
      val _ = gen_perm max_length
      val net = {basis = gs, tile_width = tile_width, grid = Grid.sequentialize grid}
      (* val ssrepdagger = Seq.map (fn (m, r) => let val rdg = GateSet.invert_perm gs r in (GateSet.perm_to_mat gs rdg, rdg) end) (#eq (#optbrute gs)) *)
      (* val _ = (#eqdagger (#optbrute gs)) := ssrepdagger *)
    in
      (* (net_stats net;  net) *)
      net
    end

  exception BaseFail

  fun nearest (given_net : net) U =
    let
      fun grid_lookup v =
        case Hashtable.lookup (#grid given_net) v of
          NONE => Seq.empty ()
        | SOME x => x
      (* val _ = print ("looking for " ^ (SMatrix.str U) ^ "\n") *)
      val num_intervals : int = Real.ceil (2.0/(#tile_width given_net))
      val cube_verts = SMatrix.all_coordinates U num_intervals
      val all_knots_seq =  Seq.flatten (Seq.map grid_lookup cube_verts)
      val _ = if (Seq.length all_knots_seq) = 0 then raise BaseFail else ()
      fun close_enough (d1, d2) = (Real.< (Real.abs (Real.- (d1, d2)), 1E~12))
      fun return_smaller ((k1,x1), (k2,x2)) =
        (* if close_enough (x1, x2) then
          if (Seq.length (#perm k1) > Seq.length (#perm k2)) then (k2, x2)
          else (k1, x1)
        else  *)
        if x1 < x2 then (k1, x1)
        else (k2, x2)
      val id = (id_knot, Real.posInf)
      val distances = Seq.map (fn kn => (kn, SMatrix.proj_trace_dist (U, #M kn))) all_knots_seq
      val (kn, sd) = Seq.reduce return_smaller id distances

      val gs = #basis given_net
      val slop = SMatrix.proj_trace_dist (U, #M kn)
      val nr' = GateSet.approx_slices gs (#M kn, #perm kn) slop
      val kn =
        case nr' of
          NONE => kn
        | SOME s => (print "slopped in nearest\n"; {M = GateSet.perm_to_mat gs s, perm = s})


      (* val sdaggerU = Seq.map (fn (m, r) => (SMatrix.multiply (m, U), r)) (!(#eqdagger (#optbrute (#basis given_net))))
      fun find_intersection s1 s2 =
        let
          bindings
        in
          body
        end *)


      (* val _ = print ("returned " ^ (SMatrix.str (#M kn)) ^ "\n") *)
      (* val _ = print ("min dist in base case = " ^ (Real.toString sd) ^ "\n") *)
      (* val (min_knot, min_dist) = Seq.reduce return_smaller id distances *)
    in
      kn
    end

  fun par (a, b) = ForkJoin.par (a, b)

  fun compose (net : net) ((V, W, U) : knot * knot * knot) (mtarget : SMatrix.t) : knot =
    let
      val gs = (#basis net)
      val VH = knot_inverse gs V
      val WH = knot_inverse gs W

      fun get_slop m cs = SMatrix.proj_trace_dist (mtarget, m)
       (* (Real./ , Real.fromInt cs)) *)

      val pseq = Seq.fromList ([#perm V, #perm W, #perm VH, #perm WH, #perm U])
      val mseq = Seq.fromList ([#M V, #M W, #M VH, #M WH, #M U])
      val mcircuit = Seq.reduce SMatrix.multiply (SMatrix.id ()) mseq
      val slop = (get_slop mcircuit (Seq.reduce op+ 0 (Seq.map Seq.length pseq)))
      val apopt = GateSet.append_perm_opt gs slop
      (* val composed_perm = Seq.reduce (fn (i, j) => apopt i j slop) (Seq.empty()) pseq *)
      val (vw, vhwh) =
        par (fn _ => apopt (#perm V) (#perm W), fn _ => apopt (#perm VH) (#perm WH))
      val vwvhwh = apopt vw vhwh
      val composed_perm = apopt vwvhwh (#perm U)
      val nr' = GateSet.approx_slices gs (GateSet.perm_to_mat gs composed_perm, composed_perm) slop
      val _ = case nr' of
        NONE => ()
      | SOME x => print "found approx with ad\n"

      (* val composed_perm' = Seq.reduce (fn (i, j) => GateSet.append_perm gs i j) (Seq.empty()) pseq *)
      (* val (m, m') = (GateSet.perm_to_mat gs composed_perm, GateSet.perm_to_mat gs composed_perm') *)
      (* val _ = if (SMatrix.equiv 1E~12 ) *)
    in
      {perm = composed_perm, M = GateSet.perm_to_mat gs composed_perm}
    end

  datatype tree = R of {arg: SMatrix.t, res: knot, u: tree, v: tree, w: tree, accuracy: Real.real}
                | B of SMatrix.t * knot * Real.real

  fun sk_tree (net : net) (U, d) =
    let
      fun do_sk (U, d) =
        if d = 0 then
          let val ukn = nearest net U
          in (ukn, B (U, ukn, SMatrix.proj_trace_dist (#M ukn, U)))
          end
        else
          let
            val (KU, ut) = do_sk (U, d-1)
            val (V, W) = SMatrix.group_factor (SMatrix.multiply (U, SMatrix.dagger (#M KU)))
            val ((KV, vt), (KW, wt)) = par (fn _ => do_sk (V, d-1), fn _ => do_sk (W, d-1))
            val KU' : knot = compose net (KV, KW, KU) U
          in
            (KU', R {arg = U, res = KU', u = ut, v = vt, w = wt, accuracy = SMatrix.proj_trace_dist (#M KU', U)})
          end
    in
      do_sk (U, d)
    end

  fun sk (net : net) (U, d) =
    let
      fun do_sk (U, d) =
        if d = 0 then nearest net U
        else
          let
            val KU = do_sk (U, d-1)
            val (V, W) = SMatrix.group_factor (SMatrix.multiply (U, SMatrix.dagger (#M KU)))
            val (KV, KW) = par (fn _ => do_sk (V, d-1), fn _ => do_sk (W, d-1))
            val KU' : knot = compose net (KV, KW, KU) U
          in
            KU'
          end
    in
      do_sk (U, d)
    end
end
