structure Parfor : PARFOR =
struct

  val w2i = Word64.toIntX
  val i2w = Word64.fromInt

  fun for (lo, hi) f =
    if lo >= hi then () else (f lo; for (lo + 1, hi) f)

  fun reduce (wlo, whi) z f merge =
      if wlo >= whi then z else reduce (wlo + 0w1, whi) (merge (z, f (w2i wlo))) f merge

  fun parfor ((lo, hi): int * int) (f: int -> unit) =
    let
      val wgrain = i2w Grains.parfor

      fun loopCheck lo hi =
        if hi - lo <= wgrain then for (w2i lo, w2i hi) f else loopSplit lo hi

      and loopSplit lo hi =
        let
          val half = Word64.>> (hi - lo, 0w1)
          val mid = lo + half
        in
          ForkJoin.par (fn _ => loopCheck lo mid, fn _ => loopCheck mid hi);
          ()
        end
    in
      if hi - lo <= Grains.parfor then for (lo, hi) f
      else loopSplit (i2w lo) (i2w hi)
    end

  fun pareduce ((lo, hi): int * int) (z: 'a) (f: int -> 'a) (merge: 'a * 'a -> 'a) =
    let
      val wgrain = i2w Grains.parfor

      fun loopCheck b lo hi =
        if hi - lo <= wgrain then reduce (lo, hi) b f merge else loopSplit b lo hi

      and loopSplit b lo hi =
        let
          val half = Word64.>> (hi - lo, 0w1)
          val mid = lo + half
        in
          merge (ForkJoin.par (fn () => loopCheck b lo mid,
                               fn () => loopCheck z mid hi))
        end
      val wlo = i2w lo
      val whi = i2w hi
    in
      if hi - lo <= Grains.parfor then reduce (wlo, whi) z f merge
      else loopSplit z wlo whi
    end
end
