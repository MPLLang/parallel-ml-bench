#pragma once

#include <iostream>
#include <cassert>

#include "benchmark.hpp"

parlay::sequence<long> primes_strict(long n) {
  if (n < 2) return parlay::sequence<long>();
  long sq = std::sqrt(n); 
  auto sqprimes = primes_strict(sq);
  parlay::sequence flags(n+1, true);
  auto sieves = parlay::map(sqprimes, [&] (long p) {
      return parlay::tabulate(n/p - 1, [&] (long m) {
	  return (m+2)*  p;});});
  auto s = parlay::flatten(sieves);
  parlay::parallel_for(0, s.size(), [&] (size_t i) {
      flags[s[i]] = false; });
  flags[0] = flags[1] = false;
  return parlay::pack_index<long>(flags);
}

parlay::sequence<long> primes_rad(long n) {
  if (n < 2) return parlay::sequence<long>();
  long sq = std::sqrt(n); 
  auto sqprimes = primes_rad(sq);
  parlay::sequence flags(n+1, true);
  auto sieves = parlay::map(sqprimes, [&] (long p) {
      return parlay::delayed_tabulate(n/p - 1, [p] (long m) {
	  return (m+2)*  p;});});
  auto s = parlay::flatten(sieves);
  parlay::parallel_for(0, s.size(), [&] (size_t i) {
    assert(s[i] < flags.size());
    flags[s[i]] = false;
  });
  flags[0] = flags[1] = false;
  return parlay::pack_index<long>(flags);
}

parlay::sequence<long> primes_delayed(long n) {
  if (n < 2) return parlay::sequence<long>();
  long sq = std::sqrt(n);
  auto sqprimes = primes_delayed(sq);
  parlay::sequence flags(n+1, true);
  auto sieves = parlay::map(sqprimes, [&] (long p) {
      return parlay::delayed_seq<long>(n/p - 1, [=] (long m) {
	  return (m+2) * p;});});
  auto s = parlay::block_delayed::flatten(sieves);
  parlay::block_delayed::apply(s, [&] (long j) {flags[j] = false;});
  flags[0] = flags[1] = false;
  return parlay::pack_index<long>(flags);
}

template <typename SeqI, typename Seq>
void inject(SeqI const &iv, Seq &s) {
  parlay::block_delayed::apply(iv, [&] (auto ivp) {s[ivp.first] = ivp.second;});
}

parlay::sequence<long> primes_delayed_pair(long n) {
  using pr = std::pair<long,bool>;
  if (n < 2) return parlay::sequence<long>();
  long sq = std::sqrt(n);
  auto sqprimes = primes_delayed(sq);
  parlay::sequence flags(n+1, true);
  auto sieves = parlay::map(sqprimes, [&] (long p) {
      return parlay::delayed_seq<pr>(n/p - 1, [=] (long m) {
	  return pr((m+2) * p, false);});});
  auto flat_sieves = parlay::block_delayed::flatten(sieves);
  inject(flat_sieves, flags);
  flags[0] = flags[1] = false;
  return parlay::pack_index<long>(flags);
}

parlay::sequence<long> primes_optimized(long n) {
  if (n < 2) return parlay::sequence<long>();
  long sq = std::sqrt(n); 
  auto sqprimes = primes_optimized(sq);
  parlay::sequence<bool> flags(n+1, true);
  parlay::parallel_for(0, sqprimes.size(), [&] (size_t i) {
      long p = sqprimes[i];
      parlay::parallel_for(0, n/p - 1, [&] (size_t m) {
	  flags[(m+2) * p] = false;});
      });
  flags[0] = flags[1] = false;  
  return parlay::pack_index<long>(flags);
}

parlay::sequence<long> primes_cache_optimized(long n) {
  if (n < 2) return parlay::sequence<long>();
  long sq = std::sqrt(n); 
  auto sqprimes = primes_cache_optimized(sq);
  parlay::sequence<bool> flags(n+1, true);
  long block_size = sq;
  parlay::parallel_for(0, n/block_size+1, [&] (long i) {
      long start = block_size * i;
      long end = std::min(start + block_size, n+1);
      for (long j = 0; j < sqprimes.size(); j++) {
	long p = sqprimes[j];
	long first = std::max(2*p,(((start-1)/p)+1)*p);
	for (long k = first; k < end; k += p) 
	  flags[k] = false;
      };}, 1);
  flags[0] = flags[1] = false;  
  return parlay::pack_index<long>(flags);
}
