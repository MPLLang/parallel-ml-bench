functor BuildSU2 (Matrix: COMPLEX_MATRIX) : SU =
struct

type t = Matrix.t
type coord =
  {t : Int16.int, x : Int16.int, y : Int16.int, z : Int16.int}

val real = Complex.real
val img = Complex.img

fun str m = Matrix.str m

fun mat m i j = Matrix.nth m (i, j)
fun cart4 m = ((real (mat m 0 0)), (~1.0 * img(mat m 0 1)), (real (mat m 1 0)), (img (mat m 1 1)))

fun det m = Matrix.det m

fun proj_trace_dist (m1, m2) =
  let
    val (t1, x1, y1, z1) = cart4 m1
    val (t2, x2, y2, z2) = cart4 m2
    val d =   (t1 - t2) * (t1 - t2)
            + (x1 - x2) * (x1 - x2)
            + (y1 - y2) * (y1 - y2)
            + (z1 - z2) * (z1 - z2)
    val n =   (t1 + t2) * (t1 + t2)
            + (x1 + x2) * (x1 + x2)
            + (y1 + y2) * (y1 + y2)
            + (z1 + z2) * (z1 + z2)
  in
    if d < n then Math.sqrt d else Math.sqrt n
  end

fun equiv epsilon (m1, m2) =
  let
    val d = proj_trace_dist (m1, m2)
  in
    Real.< (d, epsilon)
  end

fun cart4_dist (m1, m2) =
  let
    val (t1, x1, y1, z1) = cart4 m1
    val (t2, x2, y2, z2) = cart4 m2
    val (d1, d2, d3, d4) = (Real.-(t1, t2), Real.-(x1, x2), Real.-(y1, y2), Real.-(z1, z2))
    val d = Math.sqrt( Real.*(d1, d1) + Real.*(d2, d2) + Real.*(d3, d3) + Real.*(d4, d4) )
  in
    d
  end

fun canonical U =
  let
    val (t, x, y, z) = cart4 U
    val switch =
      if t > 0.0 then false
      else if t < 0.0 then true
      else if x > 0.0 then false
      else if x < 0.0 then true
      else if y > 0.0 then false
      else if y < 0.0 then true
      else if z > 0.0 then false
      else if z < 0.0 then true
      else false (* never happens for unitary *)
  in
    if switch then (Matrix.scale (~1.0, 0.0) U) else U
  end

fun negate {t, x, y, z} =
  {
    t = ~1 * t,
    x = ~1 * x,
    y = ~1 * y,
    z = ~1 * z
  }


fun ensure_first_pos (c as {t, x, y, z})  =
  if t > 0 then c
  else if t = 0 then
    if x > 0 then c
    else if x = 0 then
      if y > 0 then c
      else if y = 0 then
        if z >= 0 then c
        else negate c
      else negate c
    else negate c
  else negate c

fun coordinate m num_intervals =
  let
    val g = Real.fromInt num_intervals
    (* TODO: Does this have to be Int16?
    fun floor_corner t = (Int16.fromInt o Real.floor) (g * t + 0.5)
    *)
    fun floor_corner t = Int16.fromInt(Real.floor (g * t + 0.5))
    val (mc0, mc1, mc2, mc3) = cart4 m
  in
    ensure_first_pos
      {
        t = floor_corner mc0,
        x = floor_corner mc1,
        y =  floor_corner mc2,
        z = floor_corner mc3
      }
  end

fun coord_eq (c1 : coord, c2 : coord) = (c1 = c2)

fun compare (m1, m2) = Matrix.compare (m1, m2)

fun coord_str {t, x, y, z} = "(" ^ (Int16.toString(t)) ^ ", " ^ (Int16.toString(x)) ^ ", " ^(Int16.toString(y)) ^ ", " ^(Int16.toString(z)) ^ ")"

fun all_coordinates m num_intervals =
  let
    val g = Real.fromInt num_intervals
    fun rc t = (g * t + 0.5)
    val (mc0, mc1, mc2, mc3) = cart4 m

    fun pick_floor_ceil b =
      Int16.fromInt o (if b then Real.floor else Real.ceil)

    fun decide_floor_ceil corner_idx =
      (pick_floor_ceil (corner_idx < 8),
       pick_floor_ceil (Int.mod (corner_idx, 8) < 4),
       pick_floor_ceil (Int.mod (corner_idx, 4) < 2),
       pick_floor_ceil (Int.mod (corner_idx, 2) < 1))

    val res =
      Seq.tabulate
        (fn idx =>
          let
            val (tr, xr, yr, zr) = decide_floor_ceil idx
          in
            ensure_first_pos
              {
                t = (tr o rc) mc0,
                x = (xr o rc) mc1,
                y = (yr o rc) mc2,
                z = (zr o rc) mc3
              }
          end)
          16
  in
    res
  end


fun coord_to_polar ({t, x, y, z} : coord) =
  (* maps (t = N cosA, x = N sinA cosB, y = N sinA sinB cosC, z = N sinA sinB sinC) *)
  (* to  (N cosA, N cosB, N cosC) *)
  (* N in Int16, N > 0 *)
  (* A in [0, 2pi] *)
  (* B, C in [0, pi] ==> sin B > 0 ^ sin C > 0 *)
  let
    val (t, x, y, z) = (Int16.toInt t, Int16.toInt x, Int16.toInt y, Int16.toInt z)
    val (t_sq, x_sq, y_sq, z_sq) = (t*t, x*x, y*y, z*z)

    fun sqrt_int z = Real.round (Math.sqrt (Real.fromInt z))
    fun sign z = if (z >= 0) then 1 else ~1

    val N_sq = t_sq + x_sq + y_sq + z_sq
    val NcosA_sq = t_sq
    val NsinA_sq = N_sq - NcosA_sq
    val NcosB_sq = if NsinA_sq = 0 then N_sq else Int.div (N_sq * x_sq, NsinA_sq)
    val NsinB_sq = N_sq - NcosB_sq
    val NcosC_sq =
      if NsinA_sq = 0 andalso NsinB_sq = 0 then N_sq
      else if NsinA_sq = 0 then Int.div (N_sq * y_sq, NsinB_sq)
      else if NsinB_sq = 0 then Int.div (N_sq * y_sq, NsinA_sq)
      else Int.div (N_sq * N_sq * y_sq, NsinA_sq * NsinB_sq)

    val (p1, p2, p3) = (t, (sqrt_int NcosB_sq) * (sign z * sign x), (sqrt_int NcosC_sq) * (sign z * sign y))
  in
    (Int16.fromInt p1, Int16.fromInt p2, Int16.fromInt p3)
  end

(* val _ = coord_to_polar ({t = 7, x = 0, y = 0, z = 0} : coord) *)

fun hash (c as {t = t, x = x, y = y, z = z}) =
  let
    fun or w1 w2 = Word64.orb (w1, w2)
    fun lshift w s = Word64.<< (w, Word.fromInt s)
    (* 16 bit integers as 64 bit words (bits 16-63 are zero) *)
    val (w1, w2, w3, w4) = ((Word64.fromInt o Int16.toInt) t, (Word64.fromInt o Int16.toInt) x, (Word64.fromInt o Int16.toInt) y, (Word64.fromInt o Int16.toInt) z)
    (* compress the 4 words into 64 bits *)
    val w = or w1 (or (lshift w2 16) (or (lshift w3 32) (lshift w4 48)))
  in
    Word.fromLargeWord (Util.hash64 w)
  end


fun id () = Matrix.id (2)

fun multiply (m1 , m2) = Matrix.*(m1, m2)

val epsilon = 1E~12

fun order m =
  (* order m = min r : m^r = I *)
  let
    fun tally_order prod r =
        if equiv epsilon (prod, id()) then r
        else tally_order (multiply (m, prod)) (r+1)
  in
      tally_order m 1
  end


(* *** Functions related to group_factor *** *)

fun dot_pdt (x1, y1, z1) (x2, y2, z2) : real = x1 * x2 + y1 * y2 + z1 * z2

fun cross_pdt (x1, y1, z1) (x2, y2, z2) : real * real * real =
    (y1 * z2 - y2 * z1, x2 * z1 - x1 * z2, x1 * y2 - x2 * y1)

fun norm3 (x, y, z) = Math.sqrt(x*x + y*y + z*z)

fun normalized (x, y, z) =
  let val norm = norm3 (x, y, z)
  in
    if norm < epsilon then (1.0, 0.0, 0.0)
    else (x / norm, y / norm, z / norm)
  end

fun cart4_to_mat (t, x, y, z) =
  Matrix.fromList [[(t, ~z), (~y, ~x)], [(y, ~x), (t, z)]]


fun dagger (M : t) : t = Matrix.dagger M

fun cart3_to_mat ((nx, ny, nz), cos_phiby2 : real) =
  (* returns U = R_n(phi) given nhat = (nx, ny, nz) and cos(phi/2) *)
  let
    val sin_phiby2 = Math.sqrt(Real.abs (1.0 - cos_phiby2 * cos_phiby2))
    val (x, y, z) = (nx * sin_phiby2, ny * sin_phiby2, nz * sin_phiby2)
    val t = cos_phiby2
    val XU = cart4_to_mat (t, x, y, z)
  in
    XU
  end

fun mat_to_cart3 U =
  (* returns ((nx, ny, nz), cos_phiby2) s.t. U = R_n(phi) = exp( i phi (n.sigma) / 2) *)
  let
    val (cos_phiby2, x, y, z) = cart4 U
  in
    (normalized (x, y, z),cos_phiby2)
  end

fun similarity_matrix A B =
  (* returns S s.t. B = S A S.inv, assuming A, B are similar *)
  let
    val (na, cos_phia_by_2) = mat_to_cart3 A
    val (nb, cos_phib_by_2) = mat_to_cart3 B
    val _ =
      if Real.abs (cos_phia_by_2 - cos_phib_by_2) > epsilon then
        raise Fail "Tried to find similarity matrix of non-similar matrices"
      else
        ()
    val ns = normalized (cross_pdt na nb)
    val cos_theta = dot_pdt na nb
    val cos_thetaby2 = Math.sqrt(Real.abs((1.0 + cos_theta)/2.0))
  in
    cart3_to_mat (ns, cos_thetaby2)
  end

fun x_group_factor XU =
  (* returns balanced A, B s.t. XU = [A, B], assuming XU rotates about x-axis *)
  let
    val (t, _, y, z) = cart4 XU
    val _ = if (abs y < epsilon) orelse (abs z < epsilon) then ()
            else raise Fail "Tried to x_group_factor a matrix that was not an x-rotation"

    val sin_theta = Math.pow(Real.abs((1.0-t)/2.0), 0.25)
    val cos_theta = Math.sqrt(Real.abs(1.0 - sin_theta * sin_theta))

    val wx = sin_theta / Math.sqrt(1.0 + sin_theta * sin_theta)
    val wy = sin_theta * sin_theta / Math.sqrt(1.0 + sin_theta * sin_theta)
    val wz = cos_theta

    val W = cart3_to_mat ((wx, wy, wz), cos_theta)
    val A = cart3_to_mat ((wx, wy, ~wz), cos_theta)
    val B = similarity_matrix (dagger A) W
  in
    (A, B)
  end


(* returns balanced V, W s.t. U = [V, W], for arbitrary U in SU2 *)
fun group_factor U =
  let
    val U = canonical U
    val (cos_phiby2, _, _, _) = cart4 U
    val XU = cart3_to_mat ((1.0, 0.0, 0.0), cos_phiby2)
    val S = similarity_matrix U XU
    val (A, B) = x_group_factor XU
    val V = multiply(dagger S, multiply (A , S))
    val W = multiply(dagger S, multiply (B , S))
  in
    (V, W)
  end


fun group_commutator (A, B) =
  multiply (A, multiply (B, multiply(dagger A, dagger B)))

end

structure SU2 = BuildSU2(MatrixComplex2x2)