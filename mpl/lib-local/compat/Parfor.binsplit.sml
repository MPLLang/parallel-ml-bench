structure Parfor : PARFOR =
struct
  type word = Word64.word
  val w2i = Word64.toIntX
  val i2w = Word64.fromInt

  fun midpoint (i: word, j: word) =
      i + (Word64.>> (j - i, 0w1))

  fun wpareduce (i: word, j: word) (z: 'a) (f: word * 'a -> 'a) (merge: 'a * 'a -> 'a) =
      let fun loop (i: word, j: word) =
              if i + 0w1 >= j then
                if i >= j then
                  z
                else
                  f (i, z)
              else
                let val mid = midpoint (i, j) in
                  merge (ForkJoin.par (fn () => loop (i, mid),
                                       fn () => loop (mid, j)))
                end
      in
        loop (i, j)
      end

  fun pareduce (i, j) z f merge =
      wpareduce (i2w i, i2w j) z (fn (w, a) => f (w2i w, a)) merge
end
