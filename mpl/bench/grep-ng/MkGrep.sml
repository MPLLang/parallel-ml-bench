functor MkGrep(Seq: SEQUENCE):
sig
  val grep: char ArraySequence.t (* pattern *)
            -> char ArraySequence.t (* source text *)
            -> (int * int) ArraySequence.t (* output line ranges *)
end =
struct

  structure ASeq = ArraySequence

  type 'a seq = 'a ASeq.t

  (* check if line[i..] matches the pattern *)
  fun checkMatch pattern line i =
    (i + ASeq.length pattern <= ASeq.length line)
    andalso
    let
      val m = ASeq.length pattern
      (* pattern[j..] matches line[i+j..] *)
      fun matchesFrom j =
        (j >= m)
        orelse
        ((ASeq.nth line (i + j) = ASeq.nth pattern j)
         andalso matchesFrom (j + 1))
    in
      matchesFrom 0
    end


  fun isNewline c = (c = #"\n")
  val ff = FindFirstNG.findFirst


  fun grep pat s =
    let
      fun makeLine (start, stop) =
        ASeq.subseq s (start, stop - start)
      fun containsPat (start, stop) =
        case ff (0, stop - start) (checkMatch pat (makeLine (start, stop))) of
          NONE => NONE
        | SOME _ => SOME (start, stop)

      val s = Seq.fromArraySeq s
      val n = Seq.length s

      val idx = Seq.filter (isNewline o Seq.nth s) (Seq.tabulate (fn i => i) n)

      val m = Seq.length idx

      fun line i =
        let
          val start = if i = 0 then 0 else Seq.nth idx (i - 1)
          val stop = if i = m then n else Seq.nth idx i
        in
          (start, stop)
        end

    in
      Seq.toArraySeq (Seq.mapOption containsPat (Seq.tabulate line (m + 1)))
    end

end
