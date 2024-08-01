structure RuntimeStats:
sig
  type t
  val get: unit -> t
  val benchReport: {before: t, after: t} -> unit
end =
struct
  type t =
    { numSpawns: int
    , numEagerSpawns: int
    , numHeartbeats: int
    , numSkippedHeartbeats: int
    , numSteals: int
    , maxHeartbeatStackWalk: int
    , maxHeartbeatStackSize: int
    }

  fun get () =
    { numSpawns = ForkJoin.numSpawnsSoFar ()
    , numEagerSpawns = ForkJoin.numEagerSpawnsSoFar ()
    , numHeartbeats = ForkJoin.numHeartbeatsSoFar ()
    , numSkippedHeartbeats = ForkJoin.numSkippedHeartbeatsSoFar ()
    , numSteals = ForkJoin.numStealsSoFar ()
    , maxHeartbeatStackSize = IntInf.toInt (MPL.GC.maxStackSizeForHeartbeat ())
    , maxHeartbeatStackWalk = IntInf.toInt
        (MPL.GC.maxStackFramesWalkedForHeartbeat ())
    }

  val itos = Int.toString
  val rtos = Real.fmt (StringCvt.FIX (SOME 2))

  fun pct a b =
      if b = 0 then
        "NaN"
      else
        itos (Real.round (100.0 * (Real.fromInt a / Real.fromInt b)))

  fun benchReport {before = b: t, after = a: t} =
    let
      val numSpawns = #numSpawns a - #numSpawns b
      val numEagerSpawns = #numEagerSpawns a - #numEagerSpawns b
      val numHeartbeatSpawns = numSpawns - numEagerSpawns
      val numHeartbeats = #numHeartbeats a - #numHeartbeats b
      val numSkippedHeartbeats =
        #numSkippedHeartbeats a - #numSkippedHeartbeats b
      val numSteals = #numSteals a - #numSteals b

      val eagerp = pct numEagerSpawns numSpawns
      val hbp = pct numHeartbeatSpawns numSpawns
      val skipp = pct numSkippedHeartbeats numHeartbeats

      val spawnsPerHb = Real.fromInt numSpawns / Real.fromInt numHeartbeats
      val eagerSpawnsPerHb =
        Real.fromInt numEagerSpawns / Real.fromInt numHeartbeats
      val hbSpawnsPerHb =
        Real.fromInt numHeartbeatSpawns / Real.fromInt numHeartbeats
    in
      ( print ("======== Runtime Stats ========\n")
      ; print ("num spawns        " ^ itos numSpawns ^ "\n")
      ; print
          ("  eager           " ^ itos numEagerSpawns ^ " (" ^ eagerp
           ^ "%)\n")
      ; print
          ("  at heartbeat    " ^ itos numHeartbeatSpawns ^ " (" ^ hbp
           ^ "%)\n")

      ; print "\n"
      ; print ("num heartbeats    " ^ itos numHeartbeats ^ "\n")
      ; print
          ("  skipped         " ^ itos numSkippedHeartbeats ^ " (" ^ skipp
           ^ "%)\n")

      ; print "\n"
      ; print ("spawns / hb       " ^ rtos spawnsPerHb ^ "\n")
      ; print ("  eager           " ^ rtos eagerSpawnsPerHb ^ "\n")
      ; print ("  at heartbeat    " ^ rtos hbSpawnsPerHb ^ "\n")

      ; print "\n"
      ; print ("num steals        " ^ itos numSteals ^ "\n")

      ; print "\n"
      ; print ("max hb stack walk " ^ itos (#maxHeartbeatStackWalk a) ^ "\n")
      ; print ("max hb stack size " ^ itos (#maxHeartbeatStackSize a) ^ "\n")
      ; print ("====== End Runtime Stats ======\n")
      )
    end
end
