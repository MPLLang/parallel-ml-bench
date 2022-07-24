#include "cmdline.hpp"
#include "benchmark.hpp"

int main(int argc, char** argv) {
  size_t n = std::max((size_t)1,
    (size_t)deepsea::cmdline::parse_or_default_long("n", 100000000));
  auto input = parlay::tabulate(n, [&] (size_t i) {
    return (long)(parlay::hash64(i) % n);
  });
  parlay::sequence<long> result;

  auto cmp = [] (long a, long b) -> bool { return a < b; };

  pbbsBench::launch([&] {
    result = parlay::internal::merge_sort(parlay::make_slice(input), cmp);
  });

  for (size_t i = 0; i < std::min((size_t)10, n); i++) {
    std::cout << result[i] << " ";
  }
  std::cout << "..." << std::endl;
  return 0;
}
