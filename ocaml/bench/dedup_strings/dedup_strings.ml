let filename = Cla.parse_string "f" ""
let inputN = Cla.parse_int "N" (10 * 1000 * 1000)
let maxload = Cla.parse_float "maxload" 0.75
let initialCapacity = Cla.parse_int "init-cap" 1000

let _ = Printf.printf "Sys.int_size %d\n" Sys.int_size

let maxInt63 = 4611686018427387903

let hashInt elem =
  Int64.to_int (Int64.unsigned_rem (Util.hash64 (Int64.of_int elem)) (Int64.of_int maxInt63))

let polynomialStr str =
  (* just cap at 32 for long strings *)
  let n = Int.min 32 (String.length str) in
  let c i = Int64.of_int (Char.code (String.get str i)) in
  let rec loop h i =
    if i >= n then h
    else loop (Int64.add (Int64.mul h 31L) (c i)) (i+1)
  in
  let result = loop 7L 0 in
  Int64.to_int (Int64.unsigned_rem result (Int64.of_int maxInt63))

let hashStr str = hashInt (polynomialStr str)

let eq x y = (x = y)

let genElem (seed: int) =
  Int.to_string (hashInt seed mod inputN)

let (n, elem) =
  if filename = "" then
    (inputN, genElem)
  else
    let (contents, tm) = Benchmark.getTime (fun _ -> Readfile.contents filename) in
    let _ = Printf.printf "read file in %.03fs\n" tm in
    let is_whitespace c =
      c = ' ' || c = '\n' || c = '\r' || c = '\t' || c = '\x0C'
    in
    let ((numTokens, tokRange), tm) =
      Benchmark.getTime (fun _ ->
        (Forkjoin.run (fun _ -> Tokenize.tokenRanges is_whitespace contents)))
    in
    let _ = Printf.printf "tokenized in %.03fs\n" tm in
    let elem i =
      let (lo, hi) = tokRange i in
      Bytes.sub_string contents lo (hi-lo)
    in
    (numTokens, elem)

let _ = Printf.printf "tokens %d\n" n

let dedup () =
  let ht, _ = Benchmark.getTime (fun _ ->
    Hashset.make ~hash:hashStr ~eq:eq ~capacity:initialCapacity ~maxload:maxload)
  in
  (* Printf.printf "allocated hashtable in %.03fs\n" tm; *)
  let bucketSize = 10000 in
  let numBuckets = Util.ceilDiv n bucketSize in
  let bucketStart b = b*bucketSize in
  let bucketEnd b = Int.min ((b+1)*bucketSize) n in
  let bucketState = Seqbasis.tabulate 1000 (0, numBuckets) bucketStart in
  let bucketsTodo = Seq.tabulate (fun i -> i) numBuckets in
  let rec loop ht bucketsTodo = begin
    Forkjoin.parfor 1 (0, Seq.length bucketsTodo) (fun i ->
      let b = Seq.get bucketsTodo i in
      let start = bucketState.(b) in
      let endd = bucketEnd b in
      let rec bucketloop j =
        if j >= endd then j else
        let continue =
          try begin
            Hashset.insert ht (elem j) |> ignore;
            true
          end
          with Hashset.Full -> false
        in
        if continue then
          bucketloop (j+1)
        else
          j
      in
      bucketState.(b) <- bucketloop start
    );
    let bucketsTodo =
      Seq.filter (fun b -> bucketState.(b) < bucketEnd b) bucketsTodo
    in
    if Seq.length bucketsTodo = 0 then
      ht
    else
      loop (Hashset.resize ht) bucketsTodo
    end
  in
  loop ht bucketsTodo

let bench () = Forkjoin.run (fun _ -> dedup ())

let result = Benchmark.run "dedup_strings" bench
let _ =
  let num_unique = List.length (Hashset.to_list result) in
  Printf.printf "unique %d\n" num_unique
