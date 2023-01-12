structure RuntimeStats:
sig
  type t
  val get: unit -> t
  val benchReport: {before: t, after: t} -> unit
end =
struct
  type t = {numSpawns: int}
  fun get () = { numSpawns = ForkJoin.numSpawnsSoFar () }
  fun benchReport {before=b : t, after=a : t} =
    ( print ("======== Runtime Stats ========\n")
    ; print ("num-spawns " ^ Int.toString (#numSpawns a - #numSpawns b) ^ "\n")
    ; print ("====== End Runtime Stats ======\n")
    )
end