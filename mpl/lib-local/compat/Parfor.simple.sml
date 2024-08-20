structure Parfor : PARFOR =
struct
  val pareduce = ForkJoin.pareduce_simple
end
