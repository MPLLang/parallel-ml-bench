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
      double v = A[i];
      double vp = std::max(0.0, v);
      tu x = {vp, vp, vp, v};
      return x;
    });
  auto r = parlay::reduce(pre, parlay::make_monoid(f, identity));
  // t.next("reduce");
  return r[0];
}


auto mcss_no_gran_recursive(parlay::sequence<double> const& A, long lo, long hi) {
  using tu = std::array<double,4>;

  double neginf = std::numeric_limits<double>::lowest();

  if (lo >= hi) {
    tu result = {neginf, neginf, neginf, (double)0.0};
    return result;
  }

  if (lo+1 == hi) {
    double v = A[lo];
    double vp = std::max(0.0, v);
    tu result = {vp, vp, vp, v};
    return result;
  }

  long mid = lo + (hi-lo)/2;
  tu l, r;
  parlay::par_do(
    [&] { l = mcss_no_gran_recursive(A, lo, mid); },
    [&] { r = mcss_no_gran_recursive(A, mid, hi); }
  );

  auto f = [] (tu a, tu b) {
    tu r = {std::max(std::max(a[0],b[0]),a[2]+b[1]),
	    std::max(a[1],a[3]+b[1]),
	    std::max(a[2]+b[3],b[2]),
	    a[3]+b[3]};
    return r;};

  return f(l, r);
}

auto mcss_no_gran(parlay::sequence<double> const& A) {
  using tu = std::array<double,4>;
  tu r = mcss_no_gran_recursive(A, 0, A.size());
  return r[0];
}