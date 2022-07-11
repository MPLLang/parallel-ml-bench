#include "cmdline.hpp"
#include "benchmark.hpp"

#include "pbbsbench/common/geometry.h"
#include "pbbsbench/common/geometryIO.h"
#include "pbbsbench/common/parse_command_line.h"
#include "pbbsbench/benchmarks/delaunayTriangulation/incrementalDelaunay/delaunay.h"
#include "pbbsbench/benchmarks/delaunayTriangulation/incrementalDelaunay/delaunay.C"

using coord = double;
using point = point2d<coord>;

int main(int argc, char** argv) {
  auto infile = deepsea::cmdline::parse_or_default_string("input", "points.txt");
  parlay::sequence<point> points = readPointsFromFile<point>(infile.c_str());

  triangles<point> result;
  size_t numTriangles = 0;

  pbbsBench::launch([&] {
    result = delaunay(points);
    numTriangles = result.numTriangles();
  });

  std::cout << "number of triangles " << numTriangles << std::endl;
  return 0;
}
