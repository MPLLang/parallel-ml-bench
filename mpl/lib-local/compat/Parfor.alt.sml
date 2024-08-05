structure Parfor : PARFOR =
struct
  fun parfor (lo, hi) f =
    ForkJoin.parfor'' Grains.parfor (lo, hi) f

  fun pareduce (lo, hi) z f merge =
    ForkJoin.pareduce'' Grains.parfor (lo, hi) z f merge
end
