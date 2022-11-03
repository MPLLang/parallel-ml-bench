type grain = int

val accumulate: grain
             -> ('a -> 'a -> 'a)   (* needs to be commutative *)
             -> 'a
             -> (int * int)
             -> (int -> 'a)
             -> 'a