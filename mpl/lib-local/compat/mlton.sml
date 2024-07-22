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
  fun for (lo, hi) f =
    if lo >= hi then () else (f lo; for (lo + 1, hi) f)

  fun reduce (lo, hi) z f merge =
      if lo >= hi then z else reduce (lo + 1, hi) (merge (z, f lo)) f merge

  val parfor = for
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
