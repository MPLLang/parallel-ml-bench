#include "cmdline.hpp"
#include "benchmark.hpp"

#include "pbbsbench/common/geometry.h"
#include "pbbsbench/common/geometryIO.h"
#include "pbbsbench/common/parse_command_line.h"
#include "pbbsbench/benchmarks/nearestNeighbors/octTree/neighbors.h"

using coord = double;
using point = point2d<coord>;

template <class PT, int KK>
struct vertex {
  using pointT = PT;
  int identifier;
  pointT pt;         // the point itself
  vertex* ngh[KK];    // the list of neighbors
  vertex(pointT p, int id) : pt(p), identifier(id) {}
  size_t counter;
};

parlay::sequence<long> neighbors(parlay::sequence<point> &pts) {
  size_t n = pts.size();
  using vtx = vertex<point,1>;
  auto vv = parlay::tabulate(n, [&] (size_t i) -> vtx {
    return vtx(pts[i],i);
  });
  auto v = parlay::tabulate(n, [&] (size_t i) -> vtx* {
    return &vv[i];
  });

  ANN<1>(v, 1);

  auto result = parlay::tabulate(n, [&] (size_t i) -> long {
    return (long)(v[i]->ngh[0]->identifier);
  });

  return result;
}


int main(int argc, char** argv) {
  auto infile = deepsea::cmdline::parse_or_default_string("input", "points.txt");
  parlay::sequence<point> points = readPointsFromFile<point>(infile.c_str());

  parlay::sequence<long> result;

  pbbsBench::launch([&] {
    result = neighbors(points);
  });

  std::cout << "result ";
  for (size_t i = 0; i < std::min(result.size(), (size_t)10); i++) {
    std::cout << result[i] << " ";
  }
  std::cout << std::endl;
  return 0;
}
