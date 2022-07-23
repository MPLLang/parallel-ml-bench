#include "cmdline.hpp"
#include "benchmark.hpp"
#include "grep.h"

int main(int argc, char** argv) {
  auto infile = deepsea::cmdline::parse_or_default_string("infile", "grep.txt");
  auto pattern_str = deepsea::cmdline::parse_or_default_string("pattern", "xxy");
  auto pattern = parlay::tabulate(pattern_str.size(), [&] (size_t i) { return pattern_str[i]; });
  auto input = parlay::chars_from_file(infile.c_str(), true);
  size_t result;
  pbbsBench::launch([&] {
    auto out_str = grep_delayed(input, pattern);
    result = out_str.size();
  });
  std::cout << "result " << result << std::endl;
  return 0;
}
