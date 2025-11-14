(* structure ForkJoinNG:
sig
  val parfor: int * int -> (int -> unit) -> unit
end =
struct
  fun parfor (lo, hi) f = Util.for (lo, hi) f
end

 *)

(* structure ForkJoin = ForkJoin *)
structure Parfor : PARFOR =
struct
  fun reduce_dc (i, j) z f merge =
      if j-i = 1 then f (i, z) else
      let val mid = i + (j-i) div 2
      in merge (reduce_dc (i, mid) z f merge,
                reduce_dc (mid, j) z f merge)
      end
  
  fun reduce (lo, hi) z f merge =
    if lo >= hi then z else
      reduce_dc (lo, hi) z f merge

  val pareduce = reduce
end


structure RuntimeStats:
sig
  type t
  val get: unit -> t
  val benchReport: {before: t, after: t} -> unit
end =
struct
  type t = unit
  fun get () = ()
  fun benchReport _ =
    ( print ("======== Runtime Stats ========\n")
    ; print ("none yet...\n")
    ; print ("====== End Runtime Stats ======\n")
    )
end
