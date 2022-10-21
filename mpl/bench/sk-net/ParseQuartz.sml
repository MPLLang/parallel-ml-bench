signature PARSE_QUARTZ =
sig
  (* gives a sequence of equivalence classes.
   * each equivalence class is a sequence of circuits
   * each circuit is a sequence of labels
   *)
  val parse : string -> string Seq.t Seq.t Seq.t
  val str : string Seq.t Seq.t Seq.t -> string

  val parse_rep : string -> string Seq.t Seq.t
  val str_rep : string Seq.t Seq.t -> string
end

structure ParseQuartz : PARSE_QUARTZ =
struct
open JSON

fun to_string (STRING v) = v

fun parse f =
  let
    val p = JSONParser.openFile f

    fun list_nth l i = List.nth (l, i)
    val ARRAY lv = JSONParser.parse p
    val OBJECT d = list_nth lv 1
    val sd = Seq.fromList d
    fun parseElement (_, v) =
      let
        val ARRAY inner = v
        val sinner = Seq.fromList inner
        fun parseInner v =
          let
            val ARRAY v' = v
            val ARRAY v'' = list_nth v' 1
            val seq_gates = Seq.fromList v''
          in
            Seq.map (fn ARRAY v => to_string (list_nth v 0)) seq_gates
          end
      in
        Seq.map parseInner sinner
      end
  in
    Seq.map parseElement sd
  end

fun parse_rep f =
  let
    val p = JSONParser.openFile f
    fun list_nth l i = List.nth (l, i)
    val (ARRAY lv, tm) = Util.getTime (fn _ =>  JSONParser.parse p)
    val _ = print ("json parsed in " ^ Time.fmt 4 tm ^ "s\n")
    val sd = Seq.fromList lv
    fun parseElement (ARRAY e) =
      let
        val ARRAY e' = list_nth e 1
        val ss = Seq.fromList e'
        fun parse_gates (ARRAY g) = to_string (list_nth g 0)
      in
        Seq.map parse_gates ss
      end
  in
    Seq.map parseElement sd
  end

fun printElement s = Seq.reduce (fn (a, b) => a ^ " " ^ b) "" s

fun str_rep ss = Seq.reduce (fn (a, b) => a ^ "\n" ^ b) "" (Seq.map printElement ss)

fun str sss =
  let
    fun printClass ss = Seq.reduce (fn (a, b) => a ^ "; " ^ b) "" (Seq.map printElement ss)
  in
    Seq.reduce (fn (a, b) => a ^ "\n" ^ b) "" (Seq.map printClass sss)
  end

end

