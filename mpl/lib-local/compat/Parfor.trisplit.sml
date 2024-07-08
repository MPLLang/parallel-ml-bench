structure Parfor : PARFOR =
struct
  fun wrap msg f =
      f ()
      (*let val _ = print ("begin " ^ msg ^ "\n")
          val x = f ()
          val _ = print ("end " ^ msg ^ "\n")
      in
        x
      end*)

  fun parfor (lo, hi) f =
    wrap "parfor" (fn () => SporkJoin.parfor Grains.parfor (lo, hi) f)

  fun pareduce (lo, hi) z f merge =
    wrap "pareduce" (fn () => SporkJoin.pareduce' (lo, hi, z, f, merge))
end
