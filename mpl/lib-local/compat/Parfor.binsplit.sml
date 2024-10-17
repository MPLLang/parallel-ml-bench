structure Parfor : PARFOR =
struct
  type word = Word64.word
  val w2i = Word64.toIntX
  val i2w = Word64.fromInt

  fun pareduce (i: int, j: int) (z: 'a) (f: int * 'a -> 'a) (merge: 'a * 'a -> 'a) =
      let fun loop (i: word, j: word) =
              if i + 0w1 >= j then
                if i >= j then
                  z
                else
                  f (w2i i, z)
              else
                let val mid = i + (Word64.>> (j - i, 0w1)) in
                  merge (ForkJoin.par (fn () => loop (i, mid),
                                       fn () => loop (mid, j)))
                end
      in
        loop (i2w i, i2w j)
      end
end
