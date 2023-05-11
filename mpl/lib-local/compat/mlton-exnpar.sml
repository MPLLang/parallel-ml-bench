structure Result:
sig
  datatype 'a result = Finished of 'a | Raised of exn
  type 'a t = 'a result

  val result: (unit -> 'a) -> 'a result
  val extractResult: 'a result -> 'a
end =
struct
  datatype 'a result = Finished of 'a | Raised of exn

  type 'a t = 'a result

  fun result f =
    Finished (f ())
    handle e => Raised e

  fun extractResult r =
    case r of
      Finished x => x
    | Raised e => raise e
end


structure ForkJoin =
struct
  open ForkJoin

  fun par (f, g) =
    let val (x, y) = (Result.result f, Result.result g)
    in (Result.extractResult x, Result.extractResult y)
    end
end


structure RuntimeStats:
sig
  type t
  val get: unit -> t
  val benchReport: {before: t, after: t} -> unit
end =
struct
  type t = unit
  fun get () = ()
  fun benchReport _ =
    ( print ("======== Runtime Stats ========\n")
    ; print ("none yet...\n")
    ; print ("====== End Runtime Stats ======\n")
    )
end
