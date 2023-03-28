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

  auto result = parlay::sequence({input.cut(0, 0)});
  pbbsBench::launch([&] {
    auto ids = token_boundaries(input, is_space);
    size_t count = ids.size() / 2;
    result = parlay::tabulate(count, [&] (size_t i) {
      auto slice = input.cut(ids[2*i], ids[2*i+1]);
      /*auto str = std::string(slice.begin(), slice.end());*/
      /*return str;*/
      return slice;
    });
  });

  std::cout << "num tokens " << result.size() << std::endl;
  for (size_t i = 0; i < std::min(result.size(), (size_t)10); i++) {
    std::cout << std::string(result[i].begin(), result[i].end()) << " ";
  }
  std::cout << "..." << std::endl;
  
  return 0;
}
