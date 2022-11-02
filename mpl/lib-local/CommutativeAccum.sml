structure CommutativeAccum:
sig
  type grain = int
  val accumulate: grain
               -> ('a * 'a -> 'a)
               -> 'a
               -> (int * int)
               -> (int -> 'a)
               -> 'a
end =
struct

  type grain = int

  fun accumulate grain g z (lo, hi) f =
    if hi - lo <= grain then
      SeqBasis.foldl g z (lo, hi) f
    else
      let
        val acc = ref z

        fun put current x =
          let
            val desired = g (current, x)
            val current' = Concurrency.cas acc (current, desired)
          in
            if MLton.eq (current, current') then
              ()
            else
              put current' x
          end

        val n = hi - lo
        val m = Util.ceilDiv n grain (* number of blocks *)
      in
        ForkJoin.parfor 1 (0, m) (fn b =>
          let
            val start = lo + b * grain
            val stop = Int.min (hi, start + grain)
            val result = SeqBasis.foldl g z (start, stop) f
          in
            put (!acc) result
          end);
        
        !acc
      end

end
