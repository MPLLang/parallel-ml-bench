#include "cmdline.hpp"
#include "benchmark.hpp"

template <class F>
double integrate(const F& f, double s, double e, size_t n) {
  auto delta = (e-s)/(double)n;
  auto sp = s + delta/2.0;
  auto X = parlay::delayed_seq<double>(n, [=] (size_t i) -> double { return f(sp + (double)i * delta); });
  return parlay::reduce(X, parlay::addm<double>()) * delta;
}

int main(int argc, char** argv) {
  size_t n = std::max((size_t)1, (size_t)deepsea::cmdline::parse_or_default_long("n", 100000000));
  using T = double;
  T result;
  pbbsBench::launch([&] {
    auto f = [] (T x) {
      return sqrt(1.0 / x);
    };
    result = integrate(f, 1.0, 1000.0, n);
  });
  T correctAnswer = 61.245553203367586639977870888654371;
  std::cout << "result " << result << std::endl;
  return 0;
}

