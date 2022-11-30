structure ForkJoinNG:
sig
  val parfor: int * int -> (int -> unit) -> unit
end =
struct

  val w2i = Word64.toIntX
  val i2w = Word64.fromInt


  fun for (wlo, whi) f =
    if wlo >= whi then ()
    else (f (Word64.toIntX wlo); for (wlo+0w1, whi) f)


  fun binarySplitting f {lo, hi} () =
    if hi-lo <= OneTrueGrain.asWord64 then
      for (lo, hi) f
    else
      let
        val half = Word64.>> (hi-lo, 0w1)
        val mid = lo + half
      in
        ForkJoin.par
          ( binarySplitting f {lo=lo, hi=mid}
          , binarySplitting f {lo=mid, hi=hi}
          );
        ()
      end

  
  fun binarySplitting' f {lo, width} () =
    if width <= OneTrueGrain.asWord64 then
      for (lo, lo+width) f
    else
      let
        val half = Word64.>> (width, 0w1)
      in
        ForkJoin.par
          ( binarySplitting' f {lo=lo, width=half}
          , binarySplitting' f {lo=lo+half, width=width-half}
          );
        ()
      end


  fun parfor (lo, hi) f =
    if lo >= hi then () else
    binarySplitting f {lo = i2w lo, hi = i2w hi} ()
    (* binarySplitting' f {lo = i2w lo, width = i2w hi - i2w lo} () *)


(*
  fun binarySplittingPow2 f {lo, width} () =
    if width <= OneTrueGrain.asWord64 then
      for (lo, lo+width) f
    else
      let
        val half = Word64.>> (width, 0w1)
      in
        ForkJoin.par
          ( binarySplittingPow2 f {lo=lo, width=half}
          , binarySplittingPow2 f {lo=lo+half, width=half}
          );
        ()
      end

  fun highestPow2LessOrEqual x =
    let
      open Word64
      fun loop w x =
        if x = 0w0 then
          >> (w, 0w1)
        else
          loop (<< (w, 0w1)) (>> (x, 0w1))
    in
      loop 0w1 x
    end

  fun parfor (lo, hi) f =
    if hi-lo <= OneTrueGrain.asInt then
      Util.for (lo, hi) f
    else
    let
      val wlo = i2w lo
      val whi = i2w hi
      val width = whi - wlo
      val half = highestPow2LessOrEqual width
    in
      ForkJoin.par
        ( binarySplittingPow2 f {lo=wlo, width=half}
        , binarySplitting f {lo=wlo+half, hi=whi}
        );
      ()
    end
*)

end
