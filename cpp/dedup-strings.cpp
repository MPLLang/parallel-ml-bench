#include <iostream>
#include <cassert>
#include "cmdline.hpp"
#include "benchmark.hpp"
#include "pbbsbench/parlay/primitives.h"
#include "tokens.h"


size_t hashElem(const std::string &s) {
  // choosing this to line up with OCaml's 63-bit integers
  uint64_t maxInt63 = 4611686018427387903;
  size_t n = std::min((size_t)32, s.size());
  uint64_t h = 7;
  for (size_t i = 0; i < n; i++) {
    h = 31*h + (uint64_t)s[i];
  }
  return (size_t)parlay::hash64(h % maxInt63) % maxInt63;
}


struct Hashset {
  std::atomic<void*> * data;
  size_t capacity;
  double maxload;

  Hashset() {
    data = nullptr;
    capacity = 0;
    maxload = 0.75;
  }

  Hashset(const Hashset& other) {
    std::cout << "Hashset copy constructor not allowed" << std::endl;
    std::abort();
  }

  Hashset(Hashset&& other) {
    // std::cout << "Hashset move constructor" << std::endl;
    data = other.data;
    capacity = other.capacity;
    maxload = other.maxload;

    other.data = nullptr;
    other.capacity = 0;
  }

  Hashset& operator=(const Hashset& other) {
    std::cout << "Hashset copy assignment not allowed" << std::endl;
    std::abort();
  }

  Hashset& operator=(Hashset&& other) {
    // std::cout << "Hashset move assignment" << std::endl;
    if (this != &other) {
      clear();
      data = other.data;
      capacity = other.capacity;
      maxload = other.maxload;

      other.data = nullptr;
      other.capacity = 0;
    }
    return *this;
  }

  void clear() {
    if (data != nullptr) {
      parlay::parallel_for(0, capacity, [&] (size_t i) {
        void* x = data[i].load();
        if (x != nullptr) {
          data[i] = std::atomic(nullptr);
          std::string* s = reinterpret_cast<std::string*>(x);
          delete s;
        }
      });
      free(data);
      data = nullptr;
    }
  }

  ~Hashset() {
    clear();
  }
};


bool insert(
  Hashset &ht,
  std::string *s,
  bool makeNewCopy = true)
{
  size_t n = ht.capacity;
  size_t probes = 0;
  size_t tolerance = 2 * std::ceil(1.0 / (1.0 - ht.maxload));
  size_t i = hashElem(*s) % n;
  while (true) {
    if (probes >= tolerance) { return false; }
    if (i >= n) i = 0;
    void* curr = ht.data[i].load();
    // std::cout << "try insert " << s << " at " << i << std::endl;
    if (curr != nullptr) {
      std::string* currStrp = reinterpret_cast<std::string*>(curr);
      if (s->compare(*currStrp) == 0) {
        // std::cout << "already found " << s << " at " << i << std::endl;
        return true;
      }
      // std::cout << "slot is full at " << i << std::endl;
    } else {
      // slot is empty
      std::string* xx = (makeNewCopy ? new std::string(*s) : s);
      void* desired = reinterpret_cast<void*>(xx);
      if (ht.data[i].compare_exchange_strong(curr, desired)) {
        // std::cout << "success insert " << s << " at " << i << std::endl;
        return true;
      }
      else {
        // contention! try again
        if (makeNewCopy) delete xx;
        continue;
      }
    }
    probes++;
    i++;
  }
}


void resize(Hashset &ht)
{
  size_t cap = ht.capacity;
  size_t newCap = 2*cap;
  std::atomic<void*> * oldData = ht.data;
  std::atomic<void*> * newData =
    static_cast<std::atomic<void*> *>(malloc(newCap * sizeof(std::atomic<void*>)));
  parlay::parallel_for(0, newCap, [&] (size_t i) {
    newData[i] = std::atomic(nullptr);
  });
  ht.data = newData;
  ht.capacity = newCap;
  // auto newht = parlay::tabulate(newCap, [] (size_t i) -> std::atomic<void*> {
  //   void* np = nullptr;
  //   return std::atomic(np);
  // });
  parlay::parallel_for(0, cap, [&] (size_t i) {
    void* curr = oldData[i].load();
    oldData[i] = std::atomic(nullptr);
    if (curr != nullptr) {
      std::string* currStrp = reinterpret_cast<std::string*>(curr);
      insert(ht, currStrp, false);
    }
  });
  free(oldData);
}


size_t count(const Hashset &ht) {
  return parlay::reduce(
    parlay::delayed_tabulate(ht.capacity, [&] (size_t i) -> size_t {
      if (ht.data[i].load() != nullptr) return 1;
      return 0;
    }),
    parlay::plus<size_t>());
}


Hashset dedup(const parlay::sequence<char>& input, const parlay::sequence<size_t>& ids) {
  size_t n = ids.size() / 2;
  double maxload = 0.75;
  size_t initialCap = 1000;
  size_t bucketSize = 10000;
  size_t numBuckets = 1 + (n-1)/bucketSize;
  auto bucketStart = [&] (size_t b) -> size_t { return b*bucketSize; };
  auto bucketEnd = [&] (size_t b) -> size_t { return std::min((b+1)*bucketSize, n); };
  auto bucketState = parlay::tabulate(numBuckets, bucketStart);
  auto bucketsTodo = parlay::tabulate(numBuckets, [] (size_t b) { return b; });

  auto makeElem = [&] (size_t i) {
    auto slice = input.cut(ids[2*i], ids[2*i+1]);
    auto str = std::string(slice.begin(), slice.end());
    return str;
  };

  Hashset h;
  h.maxload = maxload;
  h.capacity = initialCap;
  h.data = static_cast<std::atomic<void*> *>(malloc(initialCap * sizeof(std::atomic<void*>)));
  parlay::parallel_for(0, initialCap, [&] (size_t i) {
    h.data[i] = std::atomic(nullptr);
  });

  while (true) {
    std::cout << "num buckets todo: " << bucketsTodo.size() << std::endl;
    parlay::parallel_for(0, bucketsTodo.size(), [&] (size_t i) {
      size_t b = bucketsTodo[i];
      size_t start = bucketState[b];
      size_t endd = bucketEnd(b);
      size_t j = start;
      while (j < endd) {
        // std::cout << "hello " << i << " " << j << std::endl;
        std::string v = makeElem(j);
        // std::cout << "wheee " << i << " " << j << std::endl;
        // std::cout << v << std::endl;
        bool isOkay = insert(h, &v, true);
        if (!isOkay) break;
        j++;
      }
      bucketState[b] = j;
    });

    bucketsTodo = parlay::filter(bucketsTodo, [&] (size_t b) {
      return bucketState[b] < bucketEnd(b);
    });

    if (bucketsTodo.size() == 0) break;
    resize(h);
  }

  return h;
}


int main(int argc, char** argv) {
  auto infile = deepsea::cmdline::parse_or_default_string("infile", "tokens.txt");
  auto input = parlay::chars_from_file(infile.c_str(), true);

  std::cout << "sizeof(std::atomic<void*>) = " << sizeof(std::atomic<void*>) << std::endl;
  std::cout << "tolerance " << 2 * std::ceil(1.0 / (1.0 - .75)) << std::endl;
  auto is_space = [] (char c) {
    switch (c)  {
    case '\r': case '\t': case '\n': case ' ' : return true;
    default : return false;
    }
  };

  auto ids = token_boundaries(input, is_space);
  size_t n = ids.size() / 2;
  std::cout << "num tokens " << n << std::endl;

  Hashset result;
  // size_t sz;
  pbbsBench::launch([&] {
    result = dedup(input, ids);
    // sz = count(result);
    // free(result.data);
  });
  std::cout << "final capacity " << result.capacity << std::endl;
  std::cout << "result " << count(result) << std::endl;

  return 0;
}