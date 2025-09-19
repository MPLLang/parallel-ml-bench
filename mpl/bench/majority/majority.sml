structure CLA = CommandLineArgs


val n = CLA.parseInt "n" (1000)
val check = CLA.parseStrings "desired"
val desired =
  if List.length check = 0 then NONE else Word64.fromString (List.hd check)

(* TODO: Fix overflow problem *)
fun makeSequenceGenerator gen =
  let
    fun generateSequence n majority_opt seed =
      let
        val unshuffled =
          case majority_opt of
            NONE => Seq.tabulate gen n
          | SOME majority_val =>
              let
                val majority_count = (n div 2) + 1
                val remaining = n - majority_count
                val majoritySeq =
                  Seq.tabulate (fn _ => majority_val) majority_count
                val otherSeq = Seq.tabulate gen remaining
              in
                Seq.append (majoritySeq, otherSeq)
              end
      in
        Shuffle.shuffle unshuffled seed
      end
  in
    generateSequence
  end


val seed = 420

val gen = fn i => Util.hash64 (Word64.xorb (Word64.fromInt i, Word64.fromInt seed))
(* Word64.fromInt (((Util.hash i) mod 1000) div 500) *)

val w64gen = makeSequenceGenerator gen

val input = w64gen n desired seed


fun task () =
  let
    val z = (0w0, 0) (* (candidate, count) *)
    (* TODO: reduce conditional checks *)
    fun combine ((lCand, lCount), (rCand, rCount)) =
      case (lCount, rCount, lCand = rCand) of
        (0, _, _) => (rCand, rCount)
      | (_, 0, _) => (lCand, lCount)
      | (_, _, true) => (lCand, lCount + rCount)
      | (_, _, false) =>
          if lCount > rCount then (lCand, lCount - rCount)
          else (rCand, rCount - lCount)
    val f = fn i => (Seq.nth input i, 1)

  in
    ForkJoin.reducem combine z (0, n) f
  end

val (candidate, count) = Benchmark.run "majority-test" task

val _ = print ("result: " ^ Word64.fmt StringCvt.DEC candidate ^ "\n")
val _ = print
  ("input"
   ^ Util.summarizeArraySlice 100 (fn w => Int.toString (Word64.toInt w)) input)
