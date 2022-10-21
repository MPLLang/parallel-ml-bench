structure CLA = CommandLineArgs


structure CliffordT =
struct
  open Math
  val (cos45, sin45) = (sqrt(0.5), sqrt(0.5))
  val x = pi/(8.0)
  val H = MatrixComplex2x2.fromList [[( 0.0, cos45), (0.0, sin45)], [(0.0, cos45), (0.0, ~sin45)]]
  val S = MatrixComplex2x2.fromList [[( cos45, ~sin45), (  0.0, 0.0)], [(  0.0, 0.0), ( cos45,  sin45)]]
  val T = MatrixComplex2x2.fromList [[(cos(x), ~(sin(x))), (  0.0, 0.0)], [(  0.0, 0.0), (cos(x), sin(x))]]
  val H_dag = SU2.dagger H
  val S_dag = SU2.dagger S
  val T_dag = SU2.dagger T
  val gates = Seq.fromList [H, S, T, H_dag, S_dag, T_dag]
  structure SU2_Net = Net (structure SMatrix = SU2 : SU; structure Grid = ParGrid; structure OptC = TrieOpt)

  exception InvalidGate

  fun labelToIdx g =
    case g of
        "h" => 0
      | "s" => 1
      | "t" => 2
      | "hdg" => 3
      | "sdg" => 4
      | "tdg" => 5
      | _ => raise InvalidGate

  fun writeFile (f: string) (s: string) : unit =
      let val os = TextIO.openOut f
      in (TextIO.output(os,s); TextIO.closeOut os)
        handle X => (TextIO.closeOut os; raise X)
      end

  fun strtoidx sss =
    let
      fun hs s = Seq.map labelToIdx s
    in
      Seq.map (fn ss => Seq.map hs ss) sss
    end

  fun lteq (c, d) =
    if (Seq.length c > Seq.length d) then false
    else if (Seq.length d > Seq.length c) then true
    else
      let
        fun countT s idx cnt =
          if idx = Seq.length s then cnt
          else if (Seq.nth s idx = 2 orelse Seq.nth s idx = 5) then countT s (idx + 1) (cnt + 1)
          else countT s (idx + 1) cnt
        val (tc, td) = (countT c 0 0, countT d 0 0)
      in
        if tc > td then false
        else if td > tc then true
        else true
      end

  fun makeRepFirst sss =
    let
      fun ltIndx ss i j = lteq (Seq.nth ss i, Seq.nth ss j)
      fun repIdx ss currMin idx =
        if idx = Seq.length ss then currMin
        else if ltIndx ss currMin idx then repIdx ss currMin (idx + 1)
        else repIdx ss idx (idx + 1)
      fun swap ss i j =
        if i = j then ()
        else let
          val si = Seq.nth ss i
          val sj = Seq.nth ss j
        in
          (ArraySlice.update (ss, i, sj); ArraySlice.update (ss, j, si))
        end
      val minIndices = Seq.map (fn ss => repIdx ss 0 0) sss
    in
      Seq.foreach sss (fn (i, ss) => swap ss 0 (Seq.nth minIndices i))
    end

  fun get_rep_seq ss =
    Seq.map
    (fn rep =>
      let
        val grep = Seq.map labelToIdx rep
      in
        (SU2_Net.GateSet.perm_to_mat_gates gates grep, grep)
      end
    ) ss

  fun insert sss t =
    let
      (* trie insertions need to be sequential *)
      fun nonpar_foreach s f =
        let
          fun loop idx max_len =
            if (idx >= Seq.length s) then max_len
            else loop (idx + 1) (Int.max (max_len, f (idx, Seq.nth s idx)))
        in
          loop 0 0
        end

      fun ins (_, ss) =
        let
          val rep = Seq.toList (Seq.nth ss 0)
        in
          nonpar_foreach ss (fn (i, s) => if (i = 0) then (Seq.length s) else (TrieOpt.insert t (Seq.toList s, rep); Seq.length s))
        end

    in
      nonpar_foreach sss ins
    end

  (* val f = CLA.parseString "filename" "test_all_5_1_complete_ECC_set.json" *)
  (* val sss = strtoidx (ParseQuartz.parse f) *)
  (* val _ = makeRepFirst sss *)
  val optc = TrieOpt.mkOpt 50
  (* val useopt = CLA.parseBool "useopt" false *)
  (* val max_len = if useopt then insert sss optc else 0 *)
  (* val _ = print ("trie insertions done " ^ (Int.toString max_len) ^ "\n") *)
  (* val optbrute = {eq = get_rep_seq sss, max_len = max_len} *)



  (* val frep = CLA.parseString "filerep" "test_26_1_representative_set.json" *)
  (* val (ssrep, tm) = Util.getTime (fn _ => ParseQuartz.parse_rep frep) *)
  (* val _ = print ("parsed filerep in " ^ Time.fmt 4 tm ^ "s\n") *)
  (* val _ = if (CLA.parseBool "dumpeq" false) then print (ParseQuartz.str_rep (ssrep)) else () *)
  (* val ml = DelayedSeq.reduce Int.max 0 (DelayedSeq.map (fn p => Seq.length p) (DelayedSeq.fromArraySeq ssrep)) *)
  val optbrute = {eq = get_rep_seq (Seq.empty()), max_len = 0, eqdagger = ref (Seq.empty())}

  (* val allrep = Seq.map (Seq.map labelToIdx) ssrep *)
  (* val _ = print "all rep done\n" *)


  val cliffordt_gates : SU2_Net.GateSet.t =
  {
    gates = gates,
    labels = Seq.fromList ["h", "s", "t", "hdg", "sdg", "tdg"] ,
    order = Seq.fromList [2, 4, 8, 2, 4, 8],
    inverses = Seq.fromList [3, 4, 5, 0, 1, 2],
    size = 6,
    optc = optc,
    optbrute = optbrute
  }

  fun idxtostr sss =
    let
      fun hs s = Seq.map (SU2_Net.GateSet.label cliffordt_gates) s
    in
      Seq.map (fn ss => Seq.map hs ss) sss
    end

  (* val sss = idxtostr sss *)

  fun writeToQASM f {perm, M} =
  let
    val header = "OPENQASM 2.0; \ninclude \"qelib1.inc\"; \nqreg q[1]; \n"
    fun write_gate i = (SU2_Net.GateSet.label cliffordt_gates i) ^ " q[0];\n"
    val gate_s = Seq.reduce (fn (a, b) => a ^ b) "" (Seq.map write_gate perm)
  in
    writeFile f (header ^ gate_s)
  end


  val tile_width = 0.3 (* eps_0 = 0.14, how does this correspond to tile_width *)
  val max_length = CLA.parseInt "pmax" 6 (* l_0 = 16, see pg6 of dawson *)
  val (sk_net) = Benchmark.run "generate_net" (fn _ => SU2_Net.generate_net (cliffordt_gates, tile_width) max_length)
  val _ = GCStats.report ()
  (* val _ = print ("net generated " ^ Time.fmt 4 tm ^ "s\n") *)

  (* val sk_net = Benchmark.run "generate_net_from_perms"  (fn _ => SU2_Net.create_net_from_perms (cliffordt_gates, tile_width, allrep)) *)


  fun synthesize (U, depth) = SU2_Net.sk sk_net (U, depth)

  fun report (U, KU) =
    (
    print ("perm = " ^ (SU2_Net.knot_to_string cliffordt_gates KU) ^ "\n");
    print ("length = " ^ (Int.toString(Seq.length (#perm KU))) ^ "\n");
    (print ("goal mat = " ^ (SU2.str (U)) ^ "\n"));
    (print ("mat = " ^ (SU2.str (#M KU)) ^ "\n"));
     print ("accuracy = " ^ (Real.toString(SU2.proj_trace_dist (#M KU, U))) ^ "\n")
    )

  fun syn_and_report (U, depth) = report (U, synthesize (U, depth))

end
