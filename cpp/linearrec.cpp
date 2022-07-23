#include "cmdline.hpp"
#include "benchmark.hpp"
#include "linearrec.h"

int main(int argc, char** argv) {
  size_t n = std::max((size_t)1, (size_t)deepsea::cmdline::parse_or_default_long("n", 100000000));
  using dpair = std::pair<double,double>;
  auto A = parlay::tabulate(n, [] (size_t i) -> dpair {
      return dpair(1.0,1.0);});
  double result;
  pbbsBench::launch([&] {
    auto rs = linear_rec_delayed(A);
    result = rs[n-1];
  });
  std::cout << "result " << result << std::endl;
  return 0;
}
