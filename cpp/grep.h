#pragma once

#include <iostream>
#include <cassert>
#include "benchmark.hpp"

auto grep_delayed(parlay::sequence<char> const& str,
		  parlay::sequence<char> const& search_str) {
  timer t("grep");
  size_t n = str.size();
  auto line_break = [] (char c) {return c == '\n';};
  auto idx = parlay::block_delayed::filter(parlay::iota(n), [&] (size_t i) -> long {
      return line_break(str[i]);});
  t.next("filter");
  size_t m = idx.size();
  //cout << m << endl;
  auto y = parlay::delayed_tabulate(m+1, [&] (size_t i) {
      size_t start = (i==0 ? 0 : idx[i-1]);
      size_t end = (i==m ? n : idx[i]);
      return parlay::make_slice(str.begin()+start,str.begin()+end);
    });
  auto r = parlay::filter(y, [&] (auto x) {
      return parlay::search(x, search_str) != x.end();});
  t.next("filter 2");
  return r;
}

auto grep_rad(parlay::sequence<char> const& str,
	      parlay::sequence<char> const& search_str) {
  timer t("grep");
  size_t n = str.size();
  auto line_break = [] (char c) {return c == '\n';};
  auto idx = parlay::filter(parlay::iota(n), [&] (size_t i) -> long {
      return line_break(str[i]);});
  t.next("filter");
  size_t m = idx.size();
  //cout << m << endl;
  auto y = parlay::delayed_tabulate(m+1, [&] (size_t i) {
      size_t start = (i==0 ? 0 : idx[i-1]);
      size_t end = (i==m ? n : idx[i]);
      return parlay::make_slice(str.begin()+start,str.begin()+end);
    });
  auto r = parlay::filter(y, [&] (auto x) {
      return parlay::search(x, search_str) != x.end();});
  t.next("filter 2");
  return r;
}

auto grep_strict(parlay::sequence<char> const& str,
		 parlay::sequence<char> const& search_str) {
  timer t("grep");
  size_t n = str.size();
  auto line_break = [] (char c) {return c == '\n';};
  auto idx = parlay::filter(parlay::iota(n), [&] (size_t i) -> long {
      return line_break(str[i]);});
  t.next("filter");
  size_t m = idx.size();
  //cout << m << endl;
  auto y = parlay::tabulate(m+1, [&] (size_t i) {
      size_t start = (i==0 ? 0 : idx[i-1]);
      size_t end = (i==m ? n : idx[i]);
      return parlay::make_slice(str.begin()+start,str.begin()+end);
    });
  auto r = parlay::filter(y, [&] (auto x) {
      return parlay::search(x, search_str) != x.end();});
  t.next("filter 2");
  return r;
}

/*
void test_grep(size_t n) {
  timer t("grep driver");
  parlay::random r(0);
  auto str = parlay::tabulate(n, [&] (size_t i) -> char {
      auto j = (r.ith_rand(i)%27);
      return (j==26) ? '\n' : (char) 97 + j;});
  std::string x("abc");
  auto search_str = parlay::to_sequence(x);
  
  {
    t.start();
    auto idxs = grep_strict(str, search_str);
    t.next("total strict");
    cout << idxs.size() << endl;
  }

  {
    t.start();
    auto idxs = grep_delayed(str, search_str);
    t.next("total delayed");
    cout << idxs.size() << endl;
  }
}
*/

// do not use ones below
/*
auto grep_delayed_old(parlay::sequence<char> const& str,
		      parlay::sequence<char> const & search_str) {
  timer t("grep");
  auto search = [&] (size_t i) -> bool{
    int j=0;
    while (j < search_str.size() && str[i+j] == search_str[j]) j++;
    return (j == search_str.size()) ;
  };
  auto line_break = [] (char c) {return c == '\n';};
  auto idx = parlay::delayed_tabulate(str.size(), [&] (long i) -> long {
      return line_break(str[i]) ? i : 0L;});
  t.next("tabulate");
  auto [prev, final] = delayed::scan(idx, parlay::maxm<long>());
  t.next("scan");
  auto foo = delayed::zip_with(parlay::iota(str.size()), prev, [&] (size_t i, long prev) {
      return search(i) ? prev : -1L;});
  t.next("zip with");
  auto r = delayed::filter(foo, [] (long i) {return i >= 0;});
  t.next("filter");
  return r;
}


auto grep_strict_old(parlay::sequence<char> const& str,
		     parlay::sequence<char> const & search_str) {
  timer t("grep");
  auto search = [&] (size_t i) -> bool{
    int j=0;
    while (j < search_str.size() && str[i+j] == search_str[j]) j++;
    return (j == search_str.size()) ;
  };
  auto line_break = [] (char c) {return c == '\n';};
  auto idx = parlay::tabulate(str.size(), [&] (long i) -> long {
      return line_break(str[i]) ? i : 0L;});
  t.next("tabulate");
  auto [prev, final] = parlay::scan(idx, parlay::maxm<long>());
  t.next("scan");
  auto foo = parlay::tabulate(str.size(), [&] (long i) -> long {
      return search(i) ? prev[i] : -1;});
  t.next("tabulate");
  auto r = parlay::filter(foo, [] (long i) {return i >= 0;});
  t.next("filter");
  return r;
}
*/
