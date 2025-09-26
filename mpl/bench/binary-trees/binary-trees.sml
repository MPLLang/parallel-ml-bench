structure CLA = CommandLineArgs

datatype 'a tree = Empty | Node of 'a tree * 'a tree

fun make d =
  if d = 0 then Node (Empty, Empty)
  else let val d = d - 1 in Node (make d, make d) end

val rec check = fn Empty => 0 | Node (l, r) => 1 + check l + check r
val min_depth = 4
val user_depth = CLA.parseInt "max-depth" (min_depth + 2)
val max_depth = 21
val stretch_depth = max_depth + 1

(* val parfor: int -> (int * int) -> (int -> unit) -> unit *)
val itos = Int.toString

val _ =
  let
    val c = check (make stretch_depth)
  in
    print
      ("stretch tree of depth " ^ itos stretch_depth ^ " check: " ^ itos c
       ^ "\n")
  end

val long_lived_tree = make max_depth

fun for (lo, hi) body =
  if lo >= hi then () else (body lo; for (lo + 1, hi) body)

fun loop_depths d : unit =
  ForkJoin.parform (0, Int.div (max_depth - d, 2) + 1) (fn i =>
    let
      val d = d + i * 2
      val niter = Word64.toInt (Word64.<< (0w1, Word64.fromInt
        (max_depth - d + min_depth)))
      val c = ref 0
    in
      ForkJoin.parform (1, niter) (fn _ => c := !c + check (make d));
      print
        (itos niter ^ " trees of depth " ^ itos d ^ " check: " ^ itos (!c)
         ^ "\n")
    end)

fun task () = loop_depths min_depth

val _ = task ()
val _ = print
  ("long lived tree of depth " ^ itos max_depth ^ " check: "
   ^ itos (check long_lived_tree))
