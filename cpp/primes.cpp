#include "cmdline.hpp"
#include "benchmark.hpp"
#include "primes.hpp"

int main(int argc, char** argv) {
  size_t n = std::max((size_t)1, (size_t)deepsea::cmdline::parse_or_default_long("n", 10000000));
  size_t numPrimes = 0;
  pbbsBench::launch([&] {

    // Performance is approximately the same here
    auto rs = primes_delayed(n);
    // auto rs = primes_optimized(n);

    numPrimes = rs.size();
  });

  std::cout << "number of primes " << numPrimes << std::endl;
  return 0;
}
