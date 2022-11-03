type grain = int

let accumulate grain g z (lo, hi) f =
  if hi - lo <= grain then
    Seqbasis.foldl g z (lo, hi) f
  else
  let acc = Atomic.make z in
  let rec put x =
    let current = Atomic.get acc in
    let desired = g current x in
    if Atomic.compare_and_set acc current desired then
      ()
    else
      put x
  in
  let n = hi - lo in
  let m = 1 + (n-1) / grain in (* number of blocks *)
  Forkjoin.parfor 1 (0, m) (fun b ->
    let start = lo + b * grain in
    let stop = Int.min hi (start + grain) in
    let result = Seqbasis.foldl g z (start, stop) f in
    put result
  );
  Atomic.get acc