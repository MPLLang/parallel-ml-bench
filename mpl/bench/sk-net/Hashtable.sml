
structure SKHashtable:
sig
  type ('a, 'b) t
  type ('a, 'b) hashtable = ('a, 'b) t

  val make: {hash: 'a -> int, eq: 'a * 'a -> bool, capacity: int} -> ('a, 'b) t
  val make_from_data: {hash: 'a -> int, eq: 'a * 'a -> bool, data:  ('a * 'b) option array} -> ('a, 'b) t

  val insert: ('a, 'b) t -> ('a * 'b) -> unit

  val lookup: ('a, 'b) t -> 'a -> 'b option
  val to_list: ('a, 'b) t -> ('a * 'b) list

  val foreach : ('a, 'b) t -> ((int * ('a * 'b) option) -> unit) -> unit

  val map :  (('a * 'b) option -> 'c) -> ('a, 'b) t -> 'c Seq.t

  val size : ('a, 'b) t -> int
end =
struct

  datatype ('a, 'b) t =
    S of
      { data: ('a * 'b) option array
      , hash: 'a -> int
      , eq: 'a * 'a -> bool
      }

  type ('a, 'b) hashtable = ('a, 'b) t

  fun make {hash, eq, capacity} =
    let
      val data = SeqBasis.tabulate 5000 (0, capacity) (fn _ => NONE)
    in
      S {data=data, hash=hash, eq=eq}
    end

  fun make_from_data {hash, eq, data} = S {data=data, hash=hash, eq=eq}


  fun bcas (arr, i) (old, new) =
    MLton.eq (old, Concurrency.casArray (arr, i) (old, new))

  fun insert (S {data, hash, eq}) (k, v) =
    let
      val n = Array.length data

      fun loop i =
        if i >= n then loop 0 else
        let
          val current = Array.sub (data, i)
          val rightPlace =
            case current of
              NONE => true
            | SOME (k', _) => eq (k, k')
        in
          if not rightPlace then
            loop (i+1)
          else if bcas (data, i) (current, SOME (k, v)) then
            ()
          else
            loop i
        end

      val start = (hash k) mod (Array.length data)
    in
      loop start
    end


  fun lookup (S {data, hash, eq}) k =
    let
      val n = Array.length data

      fun loop i =
        if i >= n then loop 0 else
        case Array.sub (data, i) of
          SOME (k', v) => if eq (k, k') then SOME v else loop (i+1)
        | NONE => NONE

      val start = (hash k) mod (Array.length data)
    in
      loop start
    end


  fun to_list (S {data, hash, eq}) =
    let
      fun pushSome (elem, xs) =
        case elem of
          SOME x => x :: xs
        | NONE => xs
    in
      Array.foldr pushSome [] data
    end

  fun size (S {data, hash, eq}) = Array.length (data)

  fun map f (S {data, hash, eq}) = Seq.map f (ArraySlice.full data)

  fun foreach (S {data, hash, eq}) f =
    Seq.foreach (ArraySlice.full data) f


end