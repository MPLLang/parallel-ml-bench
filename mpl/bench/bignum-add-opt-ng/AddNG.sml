structure AddNG =
struct
  structure Seq = ArraySequence

  type byte = Word8.word
  type bignum = byte Seq.t

  fun init (b1, b2) =
    Word8.+ (b1, b2)

  fun copy (a, b) =
    if b = 0w127 then a else b


  fun add (x, y) =
    let
      val nx = Seq.length x
      val ny = Seq.length y
      val n = Int.max (nx, ny)

      fun nthx i = if i < nx then Seq.nth x i else 0w0
      fun nthy i = if i < ny then Seq.nth y i else 0w0

      (* This algorithm is essentially a fused map-scan-map (or perhaps more
       * accurately map-scan-zip). See for example ../bignum-add/MkAdd.sml.
       * We could attempt to do fusion automatically, but this doesn't appear
       * to be performing very well at the moment (perhaps due to poor inlining
       * heuristics in the compiler). So here we manually perform the fusion
       * ourselves. The structure of this code is nearly identical to the code
       * for SeqBasisNG.scan, but we've incorporated the fused operations.
       *)
      val blockSize = Grains.block
      val numBlocks = 1 + ((n-1) div blockSize)

      val blockCarries =
        SeqBasisNG.tabulate (0, numBlocks) (fn blockIdx =>
          let
            val lo = blockIdx * blockSize
            val hi = Int.min (lo + blockSize, n)
            (* fun loop acc i =
              if i >= hi then
                acc
              else
                loop (copy (acc, init (nthx i, nthy i))) (i+1) *)
          in
            (* loop 0w127 lo *)
            SeqBasisNG.reduce copy 0w127 (lo, hi) (fn i => init (nthx i, nthy i))
          end)

      val blockPartials =
        SeqBasisNG.scan copy 0w127 (0, numBlocks)
        (fn i => Array.sub (blockCarries, i))

      val lastCarry = Array.sub (blockPartials, numBlocks)

      val result = ForkJoin.alloc (n+1)

      val _ =
        ForkJoinNG.parfor (0, numBlocks) (fn blockIdx =>
          let
            val lo = blockIdx * blockSize
            val hi = Int.min (lo + blockSize, n)

            fun loop acc i =
              if i >= hi then
                ()
              else
                let
                  val sum = init (nthx i, nthy i)
                  val acc' = copy (acc, sum)
                  val thisByte =
                    Word8.andb (Word8.+ (Word8.>> (acc, 0w7), sum), 0wx7F)
                in
                  Array.update (result, i, thisByte);
                  loop acc' (i+1)
                end
          in
            loop (Array.sub (blockPartials, blockIdx)) lo
          end)

    in
      if lastCarry > 0w127 then
        (Array.update (result, n, 0w1); ArraySlice.full result)
      else
        (ArraySlice.slice (result, 0, SOME n))
    end
end
