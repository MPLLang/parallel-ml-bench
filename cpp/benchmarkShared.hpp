#pragma once

#include <unistd.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <assert.h>
#include <sys/time.h>
#ifdef USE_HWLOC
#include <hwloc.h>
#endif
#include "cmdline.hpp"

namespace pbbsBench {

/*---------------------------------------------------------------------*/
/* Numa allocation policy via hwloc */

bool numa_alloc_interleaved_success = false;

#ifdef USE_HWLOC
hwloc_topology_t topology;
#endif

void initialize_hwloc(int nb_workers, bool numa_alloc_interleaved = true) {
#ifdef USE_HWLOC
  hwloc_topology_init(&topology);
  hwloc_topology_load(topology);
  if (numa_alloc_interleaved) {
    hwloc_cpuset_t all_cpus =
      hwloc_bitmap_dup(hwloc_topology_get_topology_cpuset(topology));
    int err = hwloc_set_membind(topology, all_cpus, HWLOC_MEMBIND_INTERLEAVE, 0);
    if (err < 0) {
      std::cerr << "failed to set NUMA round-robin allocation policy\n" << std::endl;
      exit(1);
    }
    numa_alloc_interleaved_success = true;
  }
#endif // USE_HWLOC
}

/*---------------------------------------------------------------------*/
/* Benchmark initialization */

// void setProc(int);
// void warmup(int);

/* The initialize function is guaranteed by GCC to be called by the
   system before main(), thanks to the constructor attribute on the
   function.
 */
__attribute__((constructor))
void initialize(int argc, char **argv) {
  deepsea::cmdline::set(argc, argv);
  unsigned nb_proc = deepsea::cmdline::parse_or_default_int("proc", 1);
  //setProc(nb_proc);
  { // change numa page allocation policy to round robin, if hwloc is enabled
    // and numa_alloc_interleaved==true
    bool numa_alloc_interleaved = (nb_proc == 1) ? false : true;
    numa_alloc_interleaved =
      deepsea::cmdline::parse_or_default_bool("numa_alloc_interleaved", numa_alloc_interleaved, false);
    initialize_hwloc(nb_proc, numa_alloc_interleaved);
  }
  // warmup(nb_proc);
}

template <class Bench>
void launch(const Bench& bench) {
  struct timezone tzp({0,0});
  auto get_time = [&] {
    timeval now;
    gettimeofday(&now, &tzp);
    return ((double) now.tv_sec) + ((double) now.tv_usec)/1000000.;
  };
  size_t repeat_n = deepsea::cmdline::parse_or_default_int("repeat", 1);
  double warmup_secs = deepsea::cmdline::parse_or_default_float("warmup", 3.0f);
#ifdef CILK_RUNTIME_WITH_STATS
  cilk_sync;
  __cilkg_take_snapshot_for_stats();
#endif

  if (warmup_secs > 0.0f) {
    printf ("======== WARMUP ========\n");
    double warmupStart = get_time();
    while (get_time() - warmupStart < warmup_secs) {
      auto st = get_time();
      bench();
      printf ("warmup_run %.4lfs\n", get_time() - st);
    }
    printf ("======== END WARMUP ========\n");
  }

  std::vector<double> tms;

  for (int i = 0; i < repeat_n; i++) {
    auto st = get_time();
    bench();
    auto elapsed = get_time() - st;
    printf ("time %.4lfs\n", elapsed);
    tms.push_back(elapsed);
  }
#ifdef CILK_RUNTIME_WITH_STATS
  __cilkg_dump_encore_stats_to_stderr();
#endif

  double sum = std::accumulate(tms.begin(), tms.end(), 0.0);
  printf("\naverage %.4lfs\n", sum/(double)repeat_n);
}

} // end namespace
