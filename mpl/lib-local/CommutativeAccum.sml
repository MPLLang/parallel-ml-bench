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

        fun put x =
          let
            val current = !acc
            val desired = g (current, x)
          in
            if MLton.eq (current, Concurrency.cas acc (current, desired)) then
              ()
            else
              put x
          end

        val n = hi - lo
        val m = Util.ceilDiv n grain (* number of blocks *)
      in
        ForkJoin.parfor 1 (0, m) (fn b =>
          let
            val start = b * grain
            val stop = Int.min (hi, start + grain)
          in
            put (SeqBasis.foldl g z (start, stop) f)
          end);
        
        !acc
      end

end