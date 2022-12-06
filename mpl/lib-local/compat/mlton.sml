structure ForkJoinNG:
sig
  val parfor: int * int -> (int -> unit) -> unit
end =
struct
  fun parfor (lo, hi) f = Util.for (lo, hi) f
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