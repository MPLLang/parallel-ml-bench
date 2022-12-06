structure Grains:
sig
  type grain = int
  val parfor: grain
end =
struct
  type grain = int
  val parfor = CommandLineArgs.parseInt "parfor-grain" 32
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