structure CLA = CommandLineArgs

val impl = CLA.parseString "impl" "tiled"
val bag_str = CLA.parseString "bag" "1,5,1,3,3,10,1,5,1,3,9,1,100,5,2,3,10,1,8,8,8,8,1,3,2,1,5,10,10000000,10000"
val goal = CLA.parseInt "goal" 10010021
val unsafe_skip_table_set = CLA.parseFlag "unsafe_skip_table_set"

val bag =
  Seq.fromList (List.map (valOf o Int.fromString)
    (String.tokens (fn c => c = #",") bag_str))
  handle _ => Util.die ("parsing -bag ... failed")

val _ =
  if Util.all (0, Seq.length bag) (fn i => Seq.nth bag i > 0) then ()
  else Util.die ("bag elements must be all >0")

val _ = if goal >= 0 then () else Util.die ("goal must be >=0")

val bag_str = let val s = Seq.toString Int.toString bag
              in String.substring (s, 1, String.size s - 2)
              end
val _ = print ("bag  " ^ bag_str ^ "\n")
val _ = print ("goal " ^ Int.toString goal ^ "\n")
val _ = print
  ("unsafe_skip_table_set? " ^ (if unsafe_skip_table_set then "yes" else "no")
   ^ "\n")
val _ = print ("impl " ^ impl ^ "\n")

fun bench () =
  case impl of
    "tiled" => SubsetSumTiled.subset_sum {unsafe_skip_table_set = unsafe_skip_table_set}
    (bag, goal)
  | "row-major" => SubsetSumRowMajor.subset_sum {unsafe_skip_table_set = unsafe_skip_table_set}
    (bag, goal)
  | "naive" => SubsetSumNaive.subset_sum (bag, goal)
  | _ => Util.die ("unknown -impl " ^ impl ^ "\n")

val result = Benchmark.run "subset-sum" bench

val out_str =
  case result of
    NONE => "NONE"
  | SOME x => "SOME " ^ Seq.toString Int.toString x

val _ = print ("result " ^ out_str ^ "\n")
