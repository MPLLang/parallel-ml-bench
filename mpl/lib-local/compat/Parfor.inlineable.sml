structure Parfor : PARFOR =
struct
  val pareduce = ForkJoin.pareduceInlineable
end
