structure Parfor : PARFOR =
struct
  type word = Word64.word
  val w2i = Word64.toIntX
  val i2w = Word64.fromInt

  fun for (i: word, j: word) (f: word -> unit): unit =
      if i >= j then
        ()
      else
        (f i; for (i + 0w1, j) f)

  fun reduce (i: word, j: word) (z: 'a) (f: word -> 'a) (merge: 'a * 'a -> 'a) =
      if i >= j then
        z
      else
        reduce (i + 0w1, j) (merge (z, f i)) f merge

  fun midpoint (i: word, j: word) =
      i + (Word64.>> (j - i, 0w1))

  fun wparfor (grain: word) ((i, j): word * word) (f: word -> unit) =
      let fun loop (i, j) =
              if j - i <= grain then
                for (i, j) f
              else
                let val mid = midpoint (i, j) in
                  ForkJoin.par (fn _ => loop (i, mid),
                                fn _ => loop (mid, j));
                  ()
                end
      in
        loop (i, j)
      end

  fun wpareduce (grain: word) (i: word, j: word) (z: 'a) (f: word -> 'a) (merge: 'a * 'a -> 'a) =
      let fun loop (i: word, j: word) =
              if j - i <= grain then
                reduce (i, j) z f merge
              else
                let val mid = midpoint (i, j) in
                  merge (ForkJoin.par (fn () => loop (i, mid),
                                       fn () => loop (mid, j)))
                end
      in
        loop (i, j)
      end

  fun parfor (i, j) f =
      wparfor (i2w Grains.parfor) (i2w i, i2w j) (f o w2i)

  fun pareduce (i, j) z f merge =
      wpareduce (i2w Grains.parfor) (i2w i, i2w j) z (f o w2i) merge
end
