#include "cmdline.hpp"
#include "benchmark.hpp"
#include <list>

template<typename Body>
auto sum_serial(long lo, long hi, const Body& body) {
  if (lo >= hi) return (long)0;

  long acc = body(lo);
  for (long i = lo+1; i < hi; i++) {
    acc += body(i);
  }
  return acc;
}


template<typename Body>
auto sum(long lo, long hi, const Body& body) {
  if (lo >= hi) return (long)0;
  if (lo+1 == hi) return body(lo);

  long mid = lo + (hi-lo)/2;
  long l, r;
  parlay::par_do(
    [&] { l = sum(lo, mid, body); },
    [&] { r = sum(mid, hi, body); }
  );

  return l+r;
}


struct queens {
  long row;
  long col;
  struct queens * next;
};


bool queen_is_threatened(long i, long j, struct queens * other_queens)
{
  for (struct queens * cursor = other_queens;
       cursor != NULL;
       cursor = cursor->next)
  {
    long x = cursor->row;
    long y = cursor->col;

    if (i == x || j == y || i - j == x - y || i + j == x + y) {
      return true;
    }
  }

  return false;
}


long nqueens_count_solutions_search(long n, long i, struct queens * queens)
{
  if (i >= n) return (long)1;

  auto do_column = [=] (long j) {
    if (queen_is_threatened(i, j, queens))
      return (long)0;
    struct queens new_queens;
    new_queens.row = i;
    new_queens.col = j;
    new_queens.next = queens;
    return nqueens_count_solutions_search(n, i+1, &new_queens);
  };

  return sum(0, n, do_column);
} 


long nqueens_count_solutions_search_gran_control(long n, long i, struct queens * queens)
{
  if (i >= n) return (long)1;

  auto do_column = [=] (long j) {
    if (queen_is_threatened(i, j, queens))
      return (long)0;
    struct queens new_queens;
    new_queens.row = i;
    new_queens.col = j;
    new_queens.next = queens;
    return nqueens_count_solutions_search_gran_control(n, i+1, &new_queens);
  };

  if (i >= 3)
    return sum_serial(0, n, do_column);
  else
    return sum(0, n, do_column);
} 


int main(int argc, char** argv) {
  size_t n = std::max((size_t)1, (size_t)deepsea::cmdline::parse_or_default_long("N", 13));
  std::cout << "N " << n << std::endl;
  long result;

  std::cout << std::endl << "WITH GRANULARITY CONTROL" << std::endl;
  pbbsBench::launch([&] {
    result = nqueens_count_solutions_search_gran_control(n, 0, NULL);
  });
  std::cout << "result " << result << std::endl;

  std::cout << std::endl << "NO GRANULARITY CONTROL" << std::endl;
  pbbsBench::launch([&] {
    result = nqueens_count_solutions_search(n, 0, NULL);
  });
  std::cout << "result " << result << std::endl;
  return 0;
}