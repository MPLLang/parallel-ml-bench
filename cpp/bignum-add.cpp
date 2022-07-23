#include "cmdline.hpp"
#include "benchmark.hpp"
#include "bignum-add.h"

int main(int argc, char** argv) {
  size_t n = std::max((size_t)1, (size_t)deepsea::cmdline::parse_or_default_long("n", 100000000));
  auto a = parlay::tabulate(n, [] (size_t i) -> digit {return 64;});
  auto b = parlay::tabulate(n, [] (size_t i) -> digit {return 64;});
  int result1, result2;
  pbbsBench::launch([&] {
    auto [sums, carry] = big_add_delayed(a,b);
    result1 = sums[0];
    result2 = carry;
  });
  std::cout << "result1 " << result1 << std::endl;
  std::cout << "result2 " << result2 << std::endl;
  return 0;
}
