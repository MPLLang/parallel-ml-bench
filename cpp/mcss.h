#pragma once

#include <iostream>
#include <cassert>
#include "benchmark.hpp"

auto mcss_delayed_reduce(parlay::sequence<double> const& A) {
  // timer t("mcss");
  using tu = std::array<double,4>;
  auto f = [] (tu a, tu b) {
    tu r = {std::max(std::max(a[0],b[0]),a[2]+b[1]),
	    std::max(a[1],a[3]+b[1]),
	    std::max(a[2]+b[3],b[2]),
	    a[3]+b[3]};
    return r;};
  double neginf = std::numeric_limits<double>::lowest();
  tu identity = {neginf, neginf, neginf, (double) 0.0};
  auto pre = parlay::delayed_seq<tu>(A.size(), [&] (size_t i) -> tu {
      tu x = {A[i],A[i],A[i],A[i]};
      return x;
    });
  auto r = parlay::reduce(pre, parlay::make_monoid(f, identity));
  // t.next("reduce");
  return r[0];
}
