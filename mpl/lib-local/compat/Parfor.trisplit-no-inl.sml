structure Parfor : PARFOR =
struct

  fun pareduce (i, j) z f merge = ForkJoin.pareduce (i, j) z f merge
end
