structure Parfor_grained :
sig
  val parfor_grained : int -> (int * int) -> (int -> unit) -> unit
  val pareduce_grained : int -> (int * int) -> 'a -> (int -> 'a) -> ('a * 'a -> 'a) -> 'a
end =
struct
  fun reduce (i: int, j: int) (a: 'a) (step: int * 'a -> 'a): 'a =
      if i + 1 >= j then
        if i >= j then
          a
        else
          step (i, a)
      else
        reduce (i + 1, j) (step (i, a)) step

  fun pareduce_grained (grain: int) (i: int, j: int) (b: 'a) (step: int -> 'a) (merge: 'a * 'a -> 'a): 'a =
      let val k = 1 + ((j - (i + 1)) div grain)
          fun f i = reduce (i * grain, Int.min (i * grain + grain, j)) b
                           (fn (i, b) => merge (b, step i))
      in
        Parfor.pareduce (0, k) b f
      end

  fun parfor_grained (grain: int) (i: int, j: int) (f: int -> unit): unit =
      pareduce_grained grain (i, j) () f (fn ((), ()) => ())
end
