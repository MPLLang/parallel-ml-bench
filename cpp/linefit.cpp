#include "cmdline.hpp"
#include "benchmark.hpp"

using namespace std;

template <class Seq>
auto lineFit(Seq const& points) ->
  pair<typename Seq::value_type::first_type, typename Seq::value_type::first_type> {
  using PtT = typename Seq::value_type;
  using T = typename PtT::first_type;
  T n = T(points.size());
  T xsum, ysum, Stt, bb;
  tie(xsum, ysum) = parlay::reduce(points, pair_monoid(parlay::addm<T>(), parlay::addm<T>()));
  auto xa = xsum/n;
  auto ya = ysum/n;
  auto f = [=] (PtT p) {
    T x, y;
    tie(x, y) = p;
    auto v = x - xa;
    return std::make_pair(v * v, v * y);
  };
  auto tmp = parlay::delayed_seq<PtT>(points.size(), [&] (size_t i) {
    return f(points[i]);
  });
  tie(Stt, bb) = parlay::reduce(tmp, pair_monoid(parlay::addm<T>(), parlay::addm<T>()));
  auto b = bb / Stt;
  auto a = ya - xa * b;
  return make_pair(a, b);
}

int main(int argc, char** argv) {
  using Real = double;
  size_t n = max((size_t)1, (size_t)deepsea::cmdline::parse_or_default_long("n", 1000000000));
  using PtT = pair<Real,Real>;
  auto A = parlay::tabulate(n, [] (size_t i) { return make_pair(Real(i), Real(i)); });
  Real a,b;
  pbbsBench::launch([&] {
    tie(a, b) = lineFit(A);
  });
  cout << "resulta " << a << endl;
  cout << "resultb " << b << endl;
  bool correct = abs(a) < 0.000001 && abs(b-1.0) < 0.000001;
  cout << "correct " << correct << endl;
  return 0;
}
