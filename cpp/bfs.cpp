#include <parlay/sequence.h>

#include "cmdline.hpp"
#include "benchmark.hpp"

#include "pbbsbench/common/graphIO.h"
#include "pbbsbench/benchmarks/breadthFirstSearch/simpleBFS/BFS.h"
#include "pbbsbench/benchmarks/breadthFirstSearch/simpleBFS/BFS.C"

int main(int argc, char** argv) {
  auto infile = deepsea::cmdline::parse_or_default_string("infile", "graph");
  auto source = deepsea::cmdline::parse_or_default_long("source", 0);

  Graph G = readGraphFromFile<vertexId,edgeId>(const_cast<char*>(infile.c_str()));
  G.addDegrees();

  sequence<vertexId> result;
  pbbsBench::launch([&] {
    result = BFS(source, G);
  });

  long numVisited = 0;
  for (long i = 0; i < result.size(); i++) {
    if (result[i] != -1) numVisited++;
  }

  std::cout << "visited " << numVisited << std::endl;
}
