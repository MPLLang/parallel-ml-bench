
signature SU_GRID =
sig
  type ('a, 'b) t
  exception GridFull
  val initialize : ('a -> word) ->  ('a * 'a -> bool) -> int -> ('b * 'b -> order) -> 'b -> ('a, 'b) t
  val insert : ('a, 'b) t -> ('a * 'b)  -> unit
  val sequentialize : ('a, 'b) t -> ('a, 'b Seq.t) SKHashtable.t
end
