#include <iostream>
#include <algorithm>
#include "benchmark.hpp"
#include "pbbsbench/common/geometry.h"
#include "pbbsbench/common/geometryIO.h"
#include "pbbsbench/common/parse_command_line.h"
#include "pbbsbench/benchmarks/convexHull/quickHull/hull.C"

using namespace std;

using coord = double;
using point = point2d<coord>;

int main(int argc, char** argv) {
  auto infile = deepsea::cmdline::parse_or_default_string("infile", "points.txt");
  parlay::sequence<point> Points = readPointsFromFile<point>(infile.c_str());
  indexT r;
  size_t len;
  pbbsBench::launch([&] {
    parlay::sequence<indexT> I = hull(Points);
    r = I[0];
    len = I.size();
  });
  std::cout << "size " << len << std::endl;
  std::cout << "result " << r << std::endl;
  return 0;
}
