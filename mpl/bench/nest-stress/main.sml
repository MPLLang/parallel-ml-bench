structure CLA = CommandLineArgs

val dimsize = CLA.parseInt "dimsize" 10

fun get xs acc =
   case xs of
       [] => Word.fromInt acc
     | (x :: xs) => get xs (Util.hash (x + acc))

fun bench () =
    (*let val (((a, b), (c, d)), ((e, f), (g, h))) =
            ForkJoin.par (fn () => ForkJoin.par (fn () => ForkJoin.par (fn () => 0w0, fn () => 0w1),
                                                 fn () => ForkJoin.par (fn () => 0w2, fn () => 0w3)),
                          fn () => ForkJoin.par (fn () => ForkJoin.par (fn () => 0w4, fn () => 0w5),
                                                 fn () => ForkJoin.par (fn () => 0w6, fn () => 0w7)))
    in
      a + b + c + d + e + f + g + h 
    end*)
    SeqBasisNG.reduce
      op+ 0w0 (0, dimsize)
      (fn f =>
          SeqBasisNG.reduce
            op+ 0w0 (0, dimsize)
            (fn g =>
                SeqBasisNG.reduce
                  op+ 0w0 (0, dimsize)
                  (fn h =>
                      Word.mod (get [f, g, h] 0, 0w2)
                  )
            )
      )
    (* SeqBasisNG.reduce *)
    (*   op+ 0w0 (0, dimsize) *)
    (*   (fn a => *)
    (*       SeqBasisNG.reduce *)
    (*         op+ 0w0 (0, dimsize) *)
    (*         (fn b => *)
    (*             SeqBasisNG.reduce *)
    (*               op+ 0w0 (0, dimsize) *)
    (*               (fn c => *)
    (*                   SeqBasisNG.reduce *)
    (*                     op+ 0w0 (0, dimsize) *)
    (*                     (fn d => *)
    (*                         SeqBasisNG.reduce *)
    (*                           op+ 0w0 (0, dimsize) *)
    (*                           (fn e => *)
    (*                               SeqBasisNG.reduce *)
    (*                                 op+ 0w0 (0, dimsize) *)
    (*                                 (fn f => *)
    (*                                     SeqBasisNG.reduce *)
    (*                                       op+ 0w0 (0, dimsize) *)
    (*                                       (fn g => *)
    (*                                           SeqBasisNG.reduce *)
    (*                                             op+ 0w0 (0, dimsize) *)
    (*                                             (fn h => *)
    (*                                                 Word.mod (get [a, b, c, d, e, f, g, h] 0, 0w2) *)
    (*                                             ) *)
    (*                                       ) *)
    (*                                 ) *)
    (*                           ) *)
    (*                     ) *)
    (*               ) *)
    (*         ) *)
    (*   ) *)

val result = Benchmark.run "nest-stress" bench
val _ = print ("result " ^ Word.toString result ^ "\n")
