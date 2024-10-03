structure Parfor : PARFOR =
struct

  fun __inline_always__ pareduce (i, j) z f merge = ForkJoin.pareduceSplit (i, j) z f merge
end
