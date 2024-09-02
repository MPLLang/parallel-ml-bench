structure Parfor : PARFOR =
struct
  fun __inline_always__ pareduce (i: int, j: int) (b: 'a) (step: int * 'a -> 'a) (merge: 'a * 'a -> 'a): 'a =
      ForkJoin.pareduceInlineable (i, j) b step merge
end
