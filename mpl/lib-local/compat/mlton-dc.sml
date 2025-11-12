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
  (* use mutually recursive reduces to break tail calls *)
  fun reduce (lo, hi) z f merge =
      if hi-lo <= 1 then
        if lo+1 = hi then
          f (lo, z)
        else
          z
      else
        let val mid = lo + (hi-lo) div 2
        in merge (reduce (lo, mid) z f merge,
                  reduce (mid, hi) z f merge)
        end

  (* and reduce' (lo, hi) z f merge = *)
  (*     if hi-lo <= 1 then *)
  (*       if lo+1 = hi then *)
  (*         f (lo, z) *)
  (*       else *)
  (*         z *)
  (*     else *)
  (*       let val mid = lo + (hi-lo) div 2 *)
  (*       in merge (reduce (lo, mid) z f merge, *)
  (*                 reduce (mid, hi) z f merge) *)
  (*       end *)

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
