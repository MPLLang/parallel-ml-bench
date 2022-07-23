module T = Domainslib.Task
let num_domains = Cla.parse_int "procs" 1
let mat_size = Cla.parse_int "mat_size" 1024

let k = Domain.DLS.new_key Random.State.make_self_init

module SquareMatrix = struct

  let create f : float array =
    let fa = Array.create_float (mat_size * mat_size) in
    for i = 0 to mat_size * mat_size - 1 do
      fa.(i) <- f (i / mat_size) (i mod mat_size)
    done;
    fa
  let parallel_create pool f : float array =
    let fa = Array.create_float (mat_size * mat_size) in
    T.parallel_for pool ~start:0 ~finish:( mat_size * mat_size - 1)
      ~body:(fun i -> fa.(i) <- f (i / mat_size) (i mod mat_size));
    fa

  let get (m : float array) r c = m.(r * mat_size + c)
  let set (m : float array) r c v = m.(r * mat_size + c) <- v
  let parallel_copy pool a =
    let n = Array.length a in
    let copy_part a b i =
      let s = (i * n / num_domains) in
      let e = (i+1) * n / num_domains - 1 in
      Array.blit a s b s (e - s + 1) in
    let b = Array.create_float n in
    let rec aux acc num_domains i =
      if (i = num_domains) then
        (List.iter (fun e -> T.await pool e) acc)
      else begin
        aux ((T.async pool (fun _ -> copy_part a b i))::acc) num_domains (i+1)
      end
    in
    aux [] num_domains 0;
    b
end

open SquareMatrix

let lup pool (a0 : float array) =
  let a = parallel_copy pool a0 in
  for k = 0 to (mat_size - 2) do
  T.parallel_for pool ~start:(k + 1) ~finish:(mat_size  -1)
  ~body:(fun row ->
    let factor = get a row k /. get a k k in
    for col = k + 1 to mat_size-1 do
      set a row col (get a row col -. factor *. (get a k col))
      done;
    set a row k factor )
  done ;
  a


let full_lu_decomp pool a0 =
  let lu = lup pool a0 in
  let _l = parallel_create pool (fun i j -> if i > j then get lu i j else if i = j then 1.0 else 0.0) in
  let _u = parallel_create pool (fun i j -> if i <= j then get lu i j else 0.0) in
  (_l, _u)


let () =
  let pool = T.setup_pool ~num_additional_domains:(num_domains - 1) () in
  let a = T.run pool (fun _ ->
    parallel_create pool
      (fun _ _ -> (Random.State.float (Domain.DLS.get k) 100.0) +. 1.0))
  in
  let bench () =
    T.run pool (fun _ -> full_lu_decomp pool a)
  in
  let _ = Benchmark.run "lu-decomp" bench in
  T.teardown_pool pool;
