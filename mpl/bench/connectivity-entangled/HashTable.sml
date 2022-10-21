(* Phase-concurrent hash table  *)

(* delete and find are probably incorrect, will fix later. *)

structure Hashtable = struct

  type 'a t = 'a option array * ('a -> int) * (('a * 'a) -> order)

  exception AssertionFailure
  structure A = Array
  structure AS = ArraySlice
  val update = Array.update
  val sub = Array.sub

  val gran = 10000

  fun create hash cmp n =
    let
      val t = ForkJoin.alloc n
      val () = ForkJoin.parfor gran (0, n) (fn i => update (t, i, NONE))
    in
      (t, hash, cmp)
    end

  fun nextIndex i n =
    if i = n - 1 then 0
    else i + 1

  fun prevIndex i n =
    if i = 0 then n-1
    else i-1

  fun abs_mod y n =
    if y < 0 then ~y mod n
    else y mod n

  fun insert (t, hash, cmp) x =
    let
      val n = A.length t
      fun cmp' (x, y) =
        case (x, y) of
          (NONE, NONE) => EQUAL
        | (NONE, SOME _) => LESS
        | (SOME _, NONE) => GREATER
        | (SOME x', SOME y') => cmp (x', y')
      fun probe (i, x) =
        if not (Option.isSome x) then () else
        let
          val y = sub (t, i)
        in
          case cmp' (x, y) of
            EQUAL => ()
          | LESS => probe (nextIndex i n, x)
          | GREATER =>
              let
                val z = Concurrency.casArray (t, i) (y, x)
              in
                if MLton.eq (y, z) then probe (nextIndex i n, y)
                else probe (i, x)
              end
        end
    in
      probe (abs_mod (hash x) n, SOME x)
    end

  fun findReplacement (t, hash, cmp) i =
    let
      val n = A.length t
      fun hash' v =
        case v of
          SOME vv => hash vv
        | NONE => raise AssertionFailure
      fun findRepA j =
      let
        val v = sub(t, j)
      in
        if v = NONE orelse (abs_mod (hash' v) n <= i) then (j, v)
        else findRepA (nextIndex j n)
      end
      val (j, v) = findRepA i
      val k = prevIndex j n

      fun findRepB (j, k, v) =
        if k <= i then (j, v)
        else
          let
            val v = sub (t, k)
            val (j', v') =
              if v = NONE orelse (abs_mod (hash' v) n <= i) then (k, v)
              else (j, v)
          in
            findRepB (j', k, v')
          end
    in
      findRepB (j, k, v)
    end

  fun delete (t, hash, cmp) v =
    let
      val n = A.length t
      val start = abs_mod (hash v) n
      fun findGEQ (i, v) =
        let
          val y = sub (t, i)
        in
          case y of
            NONE => i
          | SOME v' =>
            case cmp (v, v') of
              EQUAL => i
            | LESS => findGEQ (nextIndex i n, v)
            | GREATER => i
        end
      val k = findGEQ (start, v)
      fun del (i, k, v) =
        let
          val yk = sub(t, k)
        in
          if (v = NONE orelse not (v = yk)) then
            del (prevIndex i n, k, v)
          else
            let
              val (j, v') = findReplacement (t, hash, cmp) k
              val z = Concurrency.casArray (t, k) (v, v')
              val success = (z = v)
              val SOME vv = v
            in
              if success then
                if (v' = NONE) then ()
                else del (abs_mod (hash vv) n, j, v')
              else
                del (i, prevIndex k n, v)
            end
        end
    in
      del (start, k, SOME v)
    end

  fun find (t, hash, cmp) v =
    let
      val n = A.length t
      fun check i =
        if i >= n then false
        else
          let
            val v' = sub(t, i)
          in
            case v' of
              NONE => false
            | SOME v'' =>
                case cmp(v, v'') of
                  EQUAL => true
                | GREATER => false
                | LESS => check (i+1)
          end
      val hv = hash v
      val start = if (hv > 0) then (hv mod n) else (~hv mod n)
    in
      check start
    end

  fun keys (t, _, _) =
    let
      val n = A.length t
      val t' = SeqBasis.tabFilter gran (0, n) (fn i => sub (t, i))
    in
      AS.full t'
    end
end