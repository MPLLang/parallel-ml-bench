structure DenseMatColMajor:
sig
  type 'a t
  type 'a mat = 'a t

  type coord = {row: int, col: int}

  val make: {height: int, width: int} -> (coord -> 'a) -> 'a mat

  val height: 'a mat -> int
  val width: 'a mat -> int
  val get: 'a mat -> coord -> 'a
  val set: 'a mat -> coord -> 'a -> unit
  val get_col: 'a mat -> int -> 'a ArraySlice.slice

  val copy: 'a mat -> 'a mat
end =
struct

  datatype 'a t = M of {height: int, width: int, data: 'a array}
  type 'a mat = 'a t

  type coord = {row: int, col: int}

  fun make {height, width} f =
    let
      val data = ForkJoin.alloc (width * height)
    in
      ForkJoin.parform (0, width) (fn col =>
        let
          val offset = height * col
        in
          ForkJoin.parform (0, height) (fn row =>
            Array.update (data, offset + row, f {row = row, col = col}))
        end);

      M {height = height, width = width, data = data}
    end

  fun height (M {height = h, ...}) = h
  fun width (M {width = w, ...}) = w

  fun get (M {height, width, data}) {row, col} =
    Array.sub (data, height * col + row)

  fun set (M {height, width, data}) {row, col} x =
    Array.update (data, height * col + row, x)

  fun get_col (M {height, width, data}) col =
    ArraySlice.slice (data, height * col, SOME height)


  fun copy mat =
    make {height = height mat, width = width mat} (get mat)


end
