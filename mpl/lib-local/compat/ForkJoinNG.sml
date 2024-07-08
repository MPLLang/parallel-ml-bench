structure ForkJoinNG:
sig
  val parfor: int * int -> (int -> unit) -> unit
end =
struct

  fun parfor (lo, hi) f = Parfor.parfor (lo, hi) f

  (*val w2i = Word64.toIntX
  val i2w = Word64.fromInt


  fun for (wlo, whi) f =
    if wlo >= whi then () else (f (w2i wlo); for (wlo + 0w1, whi) f)


  fun parfor (lo, hi) f =
    let
      val grain = Grains.parfor
      val wgrain = i2w grain

      fun loopCheck lo hi =
        if hi - lo <= wgrain then for (lo, hi) f else loopSplit lo hi

      and loopSplit lo hi =
        let
          val half = Word64.>> (hi - lo, 0w1)
          val mid = lo + half
        in
          ForkJoin.par (fn _ => loopCheck lo mid, fn _ => loopCheck mid hi);
          ()
        end
    in
      if hi - lo <= grain then Util.for (lo, hi) f
      else loopSplit (i2w lo) (i2w hi)
    end*)

end
