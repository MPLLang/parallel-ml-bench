signature OPT_CIRCUIT =
sig
  type t
  val mkOpt : int -> t
  val insert : t -> int List.list * int List.list -> unit
  val lookup : t -> (int * (int -> int)) -> int Seq.t option
  val max_len : t -> int
end


structure TrieOpt : OPT_CIRCUIT =
struct
  type t = int
  exception Dummy
  fun mkOpt _ = 0
  fun insert _ _ = raise Dummy
  fun lookup _ _ = NONE
  fun max_len _ = raise Dummy
end
