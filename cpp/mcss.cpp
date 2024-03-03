#include "cmdline.hpp"
#include "benchmark.hpp"
#include "mcss.h"

int main(int argc, char** argv) {
  size_t n = std::max((size_t)1, (size_t)deepsea::cmdline::parse_or_default_long("n", 100000000));
  auto A = parlay::tabulate(n, [] (size_t i) -> double {
    return (double)((int)(parlay::hash64(i) % 1000) - 500) / 500.0;
  });
  double result;

  std::cout << std::endl << "WITH GRANULARITY CONTROL" << std::endl;
  pbbsBench::launch([&] {
    result = mcss_delayed_reduce(A);
  });
  std::cout << "result " << result << std::endl;

  std::cout << std::endl << "NO GRANULARITY CONTROL" << std::endl;
  pbbsBench::launch([&] {
    result = mcss_no_gran(A);
  });
  std::cout << "result " << result << std::endl;
  
  return 0;
}

