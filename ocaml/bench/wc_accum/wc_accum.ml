let is_whitespace c =
  c = ' ' || c = '\n' || c = '\r' || c = '\t' || c = '\x0C'


let wc contents =
  let f i =
    let si = Bytes.get contents i in
    let wordStart =
      if (i = 0 || is_whitespace (Bytes.get contents (i-1))) &&
         not (is_whitespace si)
      then 1 else 0
    in
    let lineBreak = if si = '\n' then 1 else 0 in
    (lineBreak, wordStart)
  in
  let lines, words =
    Accumulate.accumulate 100000
    (fun (lb1, ws1) (lb2, ws2) -> (lb1 + lb2, ws1 + ws2))
    (0, 0)
    (0, Bytes.length contents)
    f
  in
  (lines, words, Bytes.length contents)

let usage () =
  Printf.printf "usage: wc -infile FILE\n";
  exit 1

let filename = Cla.parse_string "infile" ""
let _ = if filename = "" then usage ()

let (contents, tm) = Benchmark.getTime (fun _ -> Readfile.contents filename)
let _ = Printf.printf "read file in %.03fs\n" tm


let bench () = Forkjoin.run (fun _ -> wc contents)
let (lines, words, bytes) = Benchmark.run "tokens" bench
let _ = Printf.printf "lines %d\nwords %d\nbytes %d\n" lines words bytes
