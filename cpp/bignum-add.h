#pragma once

#include <iostream>
#include <cassert>
#include "benchmark.hpp"
// #include "pbbsbench/parlaylib/include/parlay/monoid.h"

using digit = unsigned char;
using bignum = parlay::sequence<digit>;
constexpr digit BASE = 128;

auto big_add_delayed(bignum const& A, bignum const &B) {
  size_t n = A.size();
  auto sums = parlay::delayed_tabulate(n, [&] (size_t i) -> digit {
    return A[i] + B[i]; });
  auto f = [] (digit a, digit b) -> digit { // carry propagate
    return (b == BASE-1) ? a : b;};
  auto [carries, total] = parlay::delayed::scan(sums, f, digit(BASE-1));

  auto mr = parlay::delayed::zip_with([](digit carry, digit sum) -> digit {
    return ((carry >= BASE) + sum) % BASE;
  }, carries, sums);
  auto r = parlay::delayed::to_sequence(mr);

  return std::make_pair(std::move(r), (total >= BASE));
}
