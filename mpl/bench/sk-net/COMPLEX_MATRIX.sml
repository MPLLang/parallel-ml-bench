signature COMPLEX_MATRIX =
sig
  type t
  exception BadDimensions
  val nth : t ->  (int * int) -> Complex.complex
  val * : t * t -> t
  val - : (t * t) -> t
  val compare : t * t -> order
  val det : t -> Complex.complex
  val dagger : t -> t
  val fromList : Complex.complex list list -> t
  val toList : t -> Complex.complex list list
  val str : t -> string
  val id : int -> t
  val scale : Complex.complex -> t -> t
  val dimension : t -> (int * int)
  val trace : t -> Complex.complex Seq.t
  val norm : t -> Real.real
end
