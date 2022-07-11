#pragma once

#include <algorithm>

#include "pbbsbench/common/get_time.h"
#include "pbbsbench/parlay/sequence.h"
#include "pbbsbench/parlay/primitives.h"
#include "pbbsbench/parlay/parallel.h"
#include "pbbsbench/parlay/monoid.h"
#include "pbbsbench/parlaylib/include/parlay/internal/block_delayed.h"
#include "pbbsbench/parlay/random.h"
#include "pbbsbench/parlay/io.h"

#include "benchmarkShared.hpp"

namespace pbbsBench {

static
void cilk_set_nb_workers(int nb_workers) {
#if defined(PARLAY_CILK)
  int cilk_failed = __cilkrts_set_param("nworkers", std::to_string(nb_workers).c_str());
  if (cilk_failed) {
    printf("failed\n");
  }
#endif
}

void setProc(int nb_proc) {
#if defined(PARLAY_CILK)
  cilk_set_nb_workers(nb_proc);
#elif defined(PARLAY_HOMEGROWN)
  // calling this function seems to cause a crash
  //  parlay::internal::get_default_scheduler().set_num_workers(nb_proc);
#endif
}

// void warmup(int nb_proc) {
//   struct timezone tzp({0,0});
//   auto get_time = [&] {
//     timeval now;
//     gettimeofday(&now, &tzp);
//     return ((double) now.tv_sec) + ((double) now.tv_usec)/1000000.;
//   };
//   size_t dflt_warmup_n = (nb_proc == 1) ? 5 : 35;
//   size_t warmup_n = deepsea::cmdline::parse_or_default_int("warmup", dflt_warmup_n);
//   auto st = get_time();
//   for (int i = 0; i < warmup_n; i++) {
//     size_t n = 100000000;
//     auto A = parlay::tabulate(n, [] (size_t i) -> double {return 1.0;});
//   }
//   printf ("warmuptime %.4lfs\n", get_time() - st);
// }

} // end namespace
