#include "cmdline.hpp"
#include "benchmark.hpp"

using namespace std;

template <class Mat, class Vec, class Idx_Type>
auto sparseMxV(Mat const& mat, Vec const& vec) -> Vec {
  using real_type = typename Vec::value_type;
  using row_type = typename Mat::value_type;
  auto f = [&] (pair<Idx_Type, real_type> p) {
    Idx_Type i; real_type x;
    tie(i, x) = p;
    return vec[i] * x;
  };
  auto rowSum = [&] (row_type const& r) {
    return parlay::reduce(parlay::delayed_seq<double>(r.size(), [&] (size_t i) -> double { return f(r[i]); }), parlay::addm<real_type>());
  };
  return parlay::map(mat, rowSum);
}

int main(int argc, char** argv) {
  using T = int64_t;
  auto hashFn = [] (T v) { return parlay::hash64(v); };
  using real_type = double;
  size_t n = max((size_t)1, (size_t)deepsea::cmdline::parse_or_default_long("n", 100000000));
  size_t rowLen = 100;
  size_t numRows = n / rowLen;
  parlay::sequence<real_type> vec(numRows, 1.0);
  auto gen = [&] (size_t i, size_t j) { return make_pair(hashFn((i * rowLen + j)) % numRows, 1.0); };
  auto mat = parlay::tabulate(numRows, [&] (size_t i) { return parlay::tabulate(rowLen, [&] (size_t j) { return gen(i, j); }); });
  parlay::sequence<real_type> result;
  pbbsBench::launch([&] {
    result = sparseMxV<decltype(mat),decltype(vec),T>(mat, vec);
  });
  cout << "result " << result[0] << endl;
  return 0;
}
