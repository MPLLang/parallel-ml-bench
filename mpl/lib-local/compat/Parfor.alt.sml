structure Parfor : PARFOR =
struct
  (* fun parfor (lo, hi) f = *)
  (*   ForkJoin.parfor'' (lo, hi) f *)

  (* fun pareduce (lo, hi) z f merge = *)
  (*   ForkJoin.pareduce'' (lo, hi) z f merge *)
  val pareduce = ForkJoin.pareduce''
end
