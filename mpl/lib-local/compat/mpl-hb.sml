structure RuntimeStats:
sig
  type t
  val get: unit -> t
  val benchReport: {before: t, after: t} -> unit
end =
struct
  type t =
    {numSpawns: int, numEagerSpawns: int, numHeartbeats: int, numSteals: int}

  fun get () =
    { numSpawns = ForkJoin.numSpawnsSoFar ()
    , numEagerSpawns = ForkJoin.numEagerSpawnsSoFar ()
    , numHeartbeats = ForkJoin.numHeartbeatsSoFar ()
    , numSteals = ForkJoin.numStealsSoFar ()
    }

  fun benchReport {before = b: t, after = a: t} =
    ( print ("======== Runtime Stats ========\n")
    ; print
        ("num-spawns       " ^ Int.toString (#numSpawns a - #numSpawns b) ^ "\n")
    ; print
        ("num-eager-spawns "
         ^ Int.toString (#numEagerSpawns a - #numEagerSpawns b) ^ "\n")
    ; print
        ("num-heartbeats   "
         ^ Int.toString (#numHeartbeats a - #numHeartbeats b) ^ "\n")
    ; print
        ("num-steals       " ^ Int.toString (#numSteals a - #numSteals b) ^ "\n")
    ; print ("====== End Runtime Stats ======\n")
    )
end
