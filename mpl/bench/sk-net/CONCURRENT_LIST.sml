signature CONCURRENT_LIST =
sig
  type 'a t
  val mkList : 'a -> ('a * 'a -> order) -> 'a t
  val insert : 'a t -> 'a -> bool
  val lookup : 'a t -> 'a -> bool
  val size : 'a t -> int
  val foreach : 'a t -> ((int * 'a) -> unit) -> unit
end
