structure BoolTable2D:
sig
  type t
  val new: {unsafe_skip_table_set: bool} -> int * int -> t
  val set: t -> int * int -> bool -> unit
  val get: t -> int * int -> bool
end =
struct
  datatype t = T of {num_rows: int, num_cols: int, data: Word8.word array}

  fun new {unsafe_skip_table_set} (num_rows, num_cols) =
    let
      val data = ForkJoin.alloc (num_rows * num_cols)
    in
      if unsafe_skip_table_set then
        ()
      else
        ForkJoin.parfor 1000 (0, num_rows * num_cols) (fn i =>
          Array.update (data, i, 0w0 : Word8.word));
      T {num_rows = num_rows, num_cols = num_cols, data = data}
    end

  fun set (T {num_rows, num_cols, data}) (r, c) b =
    Array.update (data, r * num_cols + c, if b then 0w1 else 0w0)

  fun get (T {num_rows, num_cols, data}) (r, c) =
    Array.sub (data, r * num_cols + c) = 0w1
end
