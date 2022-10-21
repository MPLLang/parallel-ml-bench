signature SU =
sig
  type t
  type coord
  val coordinate : t -> int -> coord
  val all_coordinates : t -> int -> coord Seq.t
  val coord_eq : coord * coord -> bool
  val coord_str : coord -> string
  val hash : coord -> word
  val equiv : Real.real -> (t * t) -> bool
  (* order of matrix C is the least index such that if C^i = I *)
  val order : t -> int
  val id : unit -> t
  val multiply : t * t -> t
  val proj_trace_dist : t * t -> real
  val dagger : t -> t
  val group_factor : t -> t * t
  val group_commutator : t * t -> t
  val str : t -> string
  val det : t -> Complex.complex
  val compare : t * t -> order
end
