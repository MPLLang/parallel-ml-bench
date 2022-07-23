#pragma once

#include <iostream>
#include <cassert>
// #include "benchmark.hpp"

auto linear_rec_delayed(parlay::sequence<std::pair<double,double>> const& A) {
  using dpair = std::pair<double,double>;
  // timer t("lr");
  auto f = [] (dpair l, dpair r) {
    return dpair(l.first*r.first,l.second*r.first+r.second);};
  auto recs = parlay::delayed::scan_inclusive(A, f, dpair(1.0,0.0));
  // t.next("delayed scan");
  auto diffs = parlay::delayed::map(recs, [] (dpair x) -> long {return x.second;});
  // t.next("delayed map");
  auto r = parlay::delayed::to_sequence(diffs);
  // t.next("force");
  return r;
}
