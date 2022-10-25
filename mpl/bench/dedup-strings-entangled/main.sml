structure CLA = CommandLineArgs
val inputN = CLA.parseInt "N" (10*1000*1000)
val maxload = CLA.parseReal "maxload" 0.75
val initialCapacity = CLA.parseInt "init-cap" 1000
val filename = CLA.parseString "f" ""

val _ = print ("tolerance " ^ Int.toString (2 * Real.ceil (1.0 / (1.0 - maxload))) ^ "\n")

val _ = print ("Int.precision " ^ Int.toString (valOf Int.precision) ^ "\n")

(* choosing this to line up with OCaml's 63-bit integers *)
val maxInt63 = 4611686018427387903

fun hashInt (elem: int) : int =
  Word64.toInt (Word64.mod (Util.hash64 (Word64.fromInt elem), Word64.fromInt maxInt63))

fun polynomialStr str =
  let
    (* just cap at 32 for long strings *)
    val n = Int.min (32, String.size str)
    fun c i = Word64.fromInt (Char.ord (String.sub (str, i)))
    fun loop h i =
      if i >= n then h
      else loop (Word64.+ (Word64.* (h, 0w31), c i)) (i+1)

    val result = loop 0w7 0
  in
    Word64.toInt (Word64.mod (result, Word64.fromInt maxInt63))
  end

fun hashStr str = hashInt (polynomialStr str)

fun eq (x,y) = (x=y)

fun genElem (seed: int) =
  Util.intToString (hashInt seed mod inputN)

val (n, elem) =
  if filename = "" then
    (inputN, genElem)
  else
    let
      val (contents, tm) = Util.getTime (fn _ => ReadFile.contentsSeq filename)
      val _ = print ("read file in " ^ Time.fmt 4 tm ^ "s\n")
      val ((numTokens, tokenRange), tm) = Util.getTime (fn _ =>
        Tokenize.tokenRanges Char.isSpace contents)
      val _ = print ("tokenized in " ^ Time.fmt 4 tm ^ "s\n")
      fun elem i =
        let
          val (lo, hi) = tokenRange i
          val chars = Seq.subseq contents (lo, hi-lo)
        in
          CharVector.tabulate (Seq.length chars, Seq.nth chars)
        end
    in
      (numTokens, elem)
    end

fun dedup() =
  let
    val ht = Hashset.make
      {hash=hashStr, eq=eq, capacity=initialCapacity, maxload=maxload}

    val bucketSize = 10000
    val numBuckets = Util.ceilDiv n bucketSize
    fun bucketStart b = b*bucketSize
    fun bucketEnd b = Int.min ((b+1)*bucketSize, n)
    val bucketState =
      SeqBasis.tabulate 1000 (0, numBuckets) bucketStart

    val bucketsTodo = Seq.tabulate (fn i => i) numBuckets

    (* fun bucketsRemaining () =
      SeqBasis.reduce 1000 op+ 0 (0, numBuckets) (fn b =>
        if Array.sub (bucketState, b) < bucketEnd b then 1 else 0) *)

    fun loop ht bucketsTodo =
      let
        val _ = print ("num buckets todo: " ^ Int.toString (Seq.length bucketsTodo) ^ "\n")
        val _ =
          ForkJoin.parfor 1 (0, Seq.length bucketsTodo) (fn i =>
            let
              val b = Seq.nth bucketsTodo i
              val start = Array.sub (bucketState, b)
              val endd = bucketEnd b

              fun bucketloop j =
                if j >= endd then j else
                let
                  val continue =
                    ( Hashset.insert ht (elem j); true )
                    handle Hashset.Full => false
                in
                  if continue then
                    bucketloop (j+1)
                  else
                    j
                end
            in
              Array.update (bucketState, b, bucketloop start)
            end)

        val bucketsTodo =
          Seq.filter (fn b => Array.sub (bucketState, b) < bucketEnd b) bucketsTodo
      in
        if Seq.length bucketsTodo = 0 then
          ht
        else
          loop (Hashset.resize ht) bucketsTodo
      end
  in
    loop ht bucketsTodo
  end

val result = Benchmark.run "dedup-strings-entangled" dedup
val num_unique = List.length (Hashset.to_list result)
val _ = print ("unique " ^ Int.toString num_unique ^ "\n")

