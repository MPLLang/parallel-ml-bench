#include "cmdline.hpp"
#include "benchmark.hpp"
#include "tokens.h"

int main(int argc, char** argv) {
  auto infile = deepsea::cmdline::parse_or_default_string("infile", "tokens.txt");
  auto input = parlay::chars_from_file(infile.c_str(), true);

  auto is_space = [] (char c) {
    switch (c)  {
    case '\r': case '\t': case '\n': case ' ' : return true;
    default : return false;
    }
  };

  size_t s;
  pbbsBench::launch([&] {
    auto ids = token_boundaries(input, is_space);
    size_t count = ids.size() / 2;
    auto result = parlay::tabulate(count, [&] (size_t i) {
      auto slice = input.cut(ids[2*i], ids[2*i+1]);
      auto str = std::string(slice.begin(), slice.end());
      return str;
    });
    s = result.size();
    // for (size_t i = 0; i < std::min(s, (size_t)5); i++) {
    //   std::cout << result[i] << " ";
    // }
    // std::cout << "..." << std::endl;
  });
  std::cout << "result " << s << std::endl;
  return 0;
}
