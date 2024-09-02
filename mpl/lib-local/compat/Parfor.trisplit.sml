structure Parfor : PARFOR =
struct

  fun __inline_always__ pareduce (i, j) z f merge = ForkJoin.pareduce (i, j) z f merge
end
