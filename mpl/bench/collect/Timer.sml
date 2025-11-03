structure Timer :>
sig
  type t
  val start: unit -> t
  val tick: t -> string -> t
end =
struct

  val do_ticks = CommandLineArgs.parseFlag "ticks"

  type t = Time.time

  val current_padded_width = ref 0
  val max_padded_width = 20

fun bcas (r, old, new) =
    MLton.eq (old, Concurrency.cas r (old, new))

  fun pad m =
    let
      val len = String.size m

      fun try_set_current () =
        let
          val curr = !current_padded_width
        in
          if len >= max_padded_width orelse len <= curr then ()
          else if bcas (current_padded_width, curr, len) then
              ()
          else
            try_set_current ()
        end

      val _ = try_set_current ()
      val desired = !current_padded_width
      val padding = Int.max (0, desired - len)
    in
      CharVector.tabulate (Int.max (len, desired), fn i =>
        if i < padding then #" " else String.sub (m, i-padding))
    end

  fun start () = Time.now ()

  fun tick t msg =
    let
      val t' = Time.now ()
      val elapsed = Time.- (t', t)
    in
      if do_ticks then print ("-tick: " ^ pad msg ^ ": " ^ Time.fmt 4 elapsed ^ "s\n")
      else ();
      t'
    end

end