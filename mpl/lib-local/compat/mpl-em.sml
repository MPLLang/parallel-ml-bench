structure RuntimeStats:
sig
  type t
  val get: unit -> t
  val benchReport: {before: t, after: t} -> unit
end =
struct

  type stats = {
    lgcCount: int,
    lgcBytesReclaimed: int,
    lgcBytesInScope: int,
    lgcTracingTime: Time.time,
    lgcPromoTime: Time.time,

    cgcCount: int,
    cgcBytesReclaimed: int,
    cgcBytesInScope: int,
    cgcTime: Time.time,

    schedWorkTime: Time.time,
    schedIdleTime: Time.time,

    susMarks: int,
    deChecks: int,
    entanglements: int,
    bytesPinnedEntangled: int,
    bytesPinnedEntangledWatermark: int
  }

  datatype t = Stats of stats

  fun get () = Stats {
    lgcCount = LargeInt.toInt (MPL.GC.numLocalGCs ()),
    lgcBytesReclaimed = LargeInt.toInt (MPL.GC.localBytesReclaimed ()),
    lgcBytesInScope = LargeInt.toInt (MPL.GC.bytesInScopeForLocal ()),
    lgcTracingTime = MPL.GC.localGCTime (),
    lgcPromoTime = MPL.GC.promoTime (),

    cgcCount = LargeInt.toInt (MPL.GC.numCCs ()),
    cgcBytesReclaimed = LargeInt.toInt (MPL.GC.ccBytesReclaimed ()),
    cgcBytesInScope = LargeInt.toInt (MPL.GC.bytesInScopeForCC ()),
    cgcTime = MPL.GC.ccTime (),

    schedWorkTime = ForkJoin.workTimeSoFar (),
    schedIdleTime = ForkJoin.idleTimeSoFar (),

    susMarks = LargeInt.toInt (MPL.GC.numberSuspectsMarked ()),
    deChecks = LargeInt.toInt (MPL.GC.numberDisentanglementChecks ()),
    entanglements = LargeInt.toInt (MPL.GC.numberEntanglements ()),
    bytesPinnedEntangled = LargeInt.toInt (MPL.GC.bytesPinnedEntangled ()),
    bytesPinnedEntangledWatermark = LargeInt.toInt (MPL.GC.bytesPinnedEntangledWatermark ())
  }


  fun benchReport {before = Stats b, after = Stats a} =
    let
      fun p name (selector: stats -> 'a) (differ: 'a * 'a -> 'a) (stringer: 'a -> string) : unit =
        print (name ^ ": " ^ stringer (differ (selector a, selector b)) ^ "\n")
    in
      print ("======== Runtime Stats ========\n");
      p "sus marks" #susMarks op- Int.toString;
      p "de checks" #deChecks op- Int.toString;
      p "entanglements" #entanglements op- Int.toString;
      p "bytes pinned entangled" #bytesPinnedEntangled op- Int.toString;
      p "bytes pinned entangled watermark" #bytesPinnedEntangledWatermark #1 Int.toString;
      print "\n";
      p "lgc count" #lgcCount op- Int.toString;
      p "lgc bytes reclaimed" #lgcBytesReclaimed op- Int.toString;
      p "lgc bytes in scope" #lgcBytesInScope op- Int.toString;
      p "lgc trace time(ms)" #lgcTracingTime Time.- (LargeInt.toString o Time.toMilliseconds);
      p "lgc promo time(ms)" #lgcPromoTime Time.- (LargeInt.toString o Time.toMilliseconds);
      p "lgc total time(ms)" (fn x => Time.+ (#lgcTracingTime x, #lgcPromoTime x)) Time.- (LargeInt.toString o Time.toMilliseconds);
      print "\n";
      p "cgc count" #cgcCount op- Int.toString;
      p "cgc bytes reclaimed" #cgcBytesReclaimed op- Int.toString;
      p "cgc bytes in scope" #cgcBytesInScope op- Int.toString;
      p "cgc time(ms)" #cgcTime Time.- (LargeInt.toString o Time.toMilliseconds);
      print "\n";
      p "work time(ms)" #schedWorkTime Time.- (LargeInt.toString o Time.toMilliseconds);
      p "idle time(ms)" #schedIdleTime Time.- (LargeInt.toString o Time.toMilliseconds);
      print ("====== End Runtime Stats ======\n");
      ()
    end

end
