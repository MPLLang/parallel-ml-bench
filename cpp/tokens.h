#pragma once

#include <iostream>
#include <cassert>
#include "benchmark.hpp"

/*
template <typename F>
auto tokens_delayed(parlay::sequence<char> const& A, F is_space) {
  timer t("tokens");
  using ipair = std::pair<long,long>;
  size_t n = A.size();
  auto is_start = [&] (size_t i) {
    return ((i == 0) || is_space(A[i-1])) && !(is_space(A[i]));};
  auto is_end = [&] (size_t i) {
    return  ((i == n) || (is_space(A[i]))) && (i != 0) && !is_space(A[i-1]);};
  // associative combining function
  // first = # of starts, second = index of last start
  auto f = [] (ipair a, ipair b) {
    return (b.first == 0) ? a : ipair(a.first+b.first,b.second);};

  auto in = parlay::delayed_seq<ipair>(n+1, [&] (size_t i) -> ipair {
      return is_start(i) ? ipair(1,i) : ipair(0,0);});
  auto [offsets, sum] = parlay::delayed::scan(in, f, ipair(0,0));
  t.next("delayed scan");

  auto z = parlay::delayed::zip(offsets, parlay::iota(n+1));

  t.next("zip");
  auto r = parlay::sequence<parlay::sequence<char>>::uninitialized(sum.first);
  parlay::delayed::apply(z, [&] (auto x) {
    if (is_end(std::get<1>(x))) {
      r[std::get<0>(std::get<0>(x))] =
        parlay::to_sequence(A.cut(std::get<1>(std::get<0>(x)), std::get<1>(x)));
    }
  });
  t.next("apply");
  return r;
}
*/


template <typename F>
auto tokens_delayed(const parlay::sequence<char>& seq, F is_space) {
  size_t n = seq.size();
  auto A = seq.begin();  // Take a pointer to the buffer to avoid the overhead of SSO

  auto is_start = [&] (size_t i) { return ((i == 0) || is_space(A[i-1])) && !(is_space(A[i]));};
  auto is_end = [&] (size_t i) { return  ((i == n) || (is_space(A[i]))) && (i != 0) && !is_space(A[i-1]);};

  // associative combining function
  // first = # of starts, second = index of last start
  using ipair = std::pair<long,long>;
  auto f = [] (ipair a, ipair b) { return (b.first == 0) ? a : ipair(a.first+b.first,b.second);};

  auto in = parlay::delayed_tabulate(n+1, [&] (size_t i) -> ipair {
    return is_start(i) ? ipair(1,i) : ipair(0,0);});

  auto [offsets, sum] = parlay::delayed::scan(in, f, ipair(0,0));

  auto z = parlay::delayed::zip(offsets, parlay::iota(n+1));

  auto r = parlay::sequence<std::string>::uninitialized(sum.first);
  parlay::delayed::apply(z, [&] (auto&& x) {
    if (is_end(std::get<1>(x))) {
      auto slice = seq.cut(std::get<0>(x).second, std::get<1>(x));
      parlay::assign_uninitialized(r[std::get<0>(x).first],
        std::string(slice.begin(), slice.end()));
    }
  });

  return r;
}



template <typename F>
auto token_boundaries(const parlay::sequence<char>& seq, F is_space) {
  size_t n = seq.size();
  auto A = seq.begin();  // Take a pointer to the buffer to avoid the overhead of SSO

  auto check = [&] (size_t i) {
    if (i == n) {
      return !(is_space(A[n-1]));
    } else if (i == 0) {
      return !(is_space(A[0]));
    }
    bool i1 = is_space(A[i]);
    bool i2 = is_space(A[i-1]);
    return (i1 && !i2) || (i2 && !i1);
  };

  auto ids = parlay::filter(parlay::iota(n+1), check);
  // size_t count = ids.size() / 2;
  return ids;

  // return parlay::tabulate(count, [&] (size_t i) {
  //   auto slice = seq.cut(ids[2*i], ids[2*i+1]);
  //   auto str = std::string(slice.begin(), slice.end());
  //   return str;
  // });
}