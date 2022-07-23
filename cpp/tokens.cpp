#include "cmdline.hpp"
#include "benchmark.hpp"
#include "tokens.h"

int main(int argc, char** argv) {
  auto infile = deepsea::cmdline::parse_or_default_string("infile", "tokens.txt");
  auto input = parlay::chars_from_file(infile.c_str(), true);

  // auto str = parlay::tabulate(n, [] (size_t i) -> char {
  //   return (i%8 == 0) ? ' ' : 'a';});

  auto is_space = [] (char c) {
    switch (c)  {
    case '\r': case '\t': case '\n': case ' ' : return true;
    default : return false;
    }
  };
  using ipair = std::pair<long,long>;
  size_t s;
  pbbsBench::launch([&] {
    auto xd = tokens_delayed(input, is_space);
    s = xd.size();
  });
  std::cout << "result " << s << std::endl;
  return 0;
}
