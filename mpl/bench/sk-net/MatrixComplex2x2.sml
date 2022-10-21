
structure MatrixComplex2x2 : COMPLEX_MATRIX =
struct
  type t = (Complex.complex * Complex.complex * Complex.complex * Complex.complex)

  exception BadDimensions
  exception Unimplemented
  fun nth (a, b, c, d) (0, 0) = a
    | nth (a, b, c, d) (0, 1) = b
    | nth (a, b, c, d) (1, 0) = c
    | nth (a, b, c, d) (1, 1) = d
    | nth _ _ = raise BadDimensions

  fun det (a, b, c, d) = (Complex.sub (Complex.multiply (a, d), Complex.multiply (b, c)))

  fun dimension _ = (2, 2)

  fun scale s (a, b, c, d) =
    (Complex.multiply (s, a), Complex.multiply (s, b), Complex.multiply (s, c), Complex.multiply (s, d))

  fun round_to_zero p (a, b, c, d) =
    (Complex.round p a, Complex.round p b, Complex.round p c, Complex.round p d)

  fun multiply ((a00, a01, a10, a11), (b00, b01, b10, b11)) =
    round_to_zero 1E~14
    (
      Complex.add (Complex.multiply (a00, b00), Complex.multiply (a01, b10)),
      Complex.add (Complex.multiply (a00, b01), Complex.multiply (a01, b11)),
      Complex.add (Complex.multiply (a10, b00), Complex.multiply (a11, b10)),
      Complex.add (Complex.multiply (a10, b01), Complex.multiply (a11, b11))
    )
  fun a * b = multiply (a, b)
  fun a - b = raise Unimplemented
  fun norm _ = raise Unimplemented

  fun dagger (a, b, c, d) = (Complex.conjugate a, Complex.conjugate c, Complex.conjugate b, Complex.conjugate d)

  fun str (a, b, c, d) =
    let
      val row0 = "(" ^ (Complex.str a) ^ ", " ^ (Complex.str b) ^ ")"
      val row1 = "(" ^ (Complex.str c) ^ ", " ^ (Complex.str d) ^ ")"
    in
      "(" ^ row0 ^ ", " ^ row1 ^ ")\n"
    end

  fun fromList [[a, b],[c, d]] = (a, b, c, d)
    | fromList _ = raise BadDimensions
  fun toList   (a, b, c, d) = [[a, b], [c, d]]

  fun id _ = fromList [[(1.0, 0.0), (0.0,  0.0)], [(0.0, 0.0), ( 1.0, 0.0)]]

  fun compare ((a1, a2, a3, a4), (b1, b2, b3, b4)) =
    case Complex.compare (a1, b1) of
      EQUAL =>
      (case Complex.compare (a2, b2) of
        EQUAL =>
        (case Complex.compare (a3, b3) of
          EQUAL => Complex.compare (a4, b4)
        | lg => lg)
      | lg => lg)
    | lg => lg

  fun trace (a1, a2, a3, a4) = Seq.fromList ([a1, a4])
end
