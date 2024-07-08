signature PARFOR =
sig
  val parfor : (int * int) -> (int -> unit) -> unit
  val pareduce : (int * int) -> 'a -> (int -> 'a) -> ('a * 'a -> 'a) -> 'a
end
