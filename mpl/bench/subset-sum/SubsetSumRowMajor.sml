structure SubsetSumRowMajor:
sig
  val subset_sum: {unsafe_skip_table_set: bool}
                  -> int Seq.t * int
                  -> int Seq.t option
end =
struct

  structure Table = BoolTable2D

  fun subset_sum {unsafe_skip_table_set} (bag: int Seq.t, goal: int) :
    int Seq.t option =
    let
      val n = Seq.length bag

      val table =
        Table.new {unsafe_skip_table_set = unsafe_skip_table_set}
          (1 + n, 1 + goal)
      fun get (r, c) = Table.get table (r, c)
      fun set (r, c) b =
        Table.set table (r, c) b

      fun do_node (i, j) =
        if j = 0 then set (i, j) true
        else if i >= n then set (i, j) false
        else if Seq.nth bag i > j then set (i, j) (get (i + 1, j))
        else set (i, j) (get (i + 1, j) orelse get (i + 1, j - Seq.nth bag i))

      fun reconstruct_path acc (i, j) =
        if j = 0 then
          Seq.fromRevList acc
        else
          let
            val x = Seq.nth bag i
          in
            if get (i + 1, j) then reconstruct_path acc (i + 1, j)
            else reconstruct_path (x :: acc) (i + 1, j - x)
          end
    in
      Util.forBackwards (0, n + 1) (fn i =>
        ForkJoin.parform (0, goal + 1) (fn j => do_node (i, j)));

      if get (0, goal) then SOME (reconstruct_path [] (0, goal)) else NONE
    end

end
