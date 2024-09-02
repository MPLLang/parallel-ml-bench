structure WC :
sig
  (* returns (num lines, num words, num characters) *)
  val wc: int * (int -> char) -> (int * int * int)
end =
struct

  fun wc (len, nth) =
    let
      fun isSpace a = (a = #"\n" orelse a = #"\t" orelse a = #" ")
      fun f i =
        let
          val si = nth i
          val wordStart =
            if (i = 0 orelse isSpace (nth (i-1))) andalso
               not (isSpace si)
            then 1 else 0
          val lineBreak = if si = #"\n" then 1 else 0
        in
          (lineBreak, wordStart)
        end
      val (lines, words) =
        SeqBasisNG.reduce
          (fn ((lb1, ws1), (lb2, ws2)) => (lb1 + lb2, ws1 + ws2))
          (0, 0)
          (0, len)
          f
          
    in
      (lines, words, len)
    end

end
