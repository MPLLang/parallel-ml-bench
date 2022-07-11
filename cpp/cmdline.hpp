#pragma once

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <string>
#include <iostream>
#include <map>
#include <functional>

namespace deepsea {
namespace cmdline {
  
namespace {
  
  int global_argc = -1;
  char** global_argv;
  
  bool print_warning_on_use_of_default_value = false;
  
  static void failure() {
    printf("Error illegal command line\n");
    exit(-1);
  }
  
  static void check_set() {
    if (global_argc == -1) {
      printf("you must call cmdline::set(argc,argv) in your main.");
      exit(-1);
    }
  }
  
  static void check(std::string name, bool result) {
    if (! result) {
      printf("missing command line argument %s\n", name.c_str());
      exit(-1);
    }
  }
  
  template <class T>
  void print_default(std::string name, T val, bool expected) {
    if (! expected || ! print_warning_on_use_of_default_value)
      return;
    std::cerr << "Warning: using default for " << name << " " << val << std::endl;
  }
  
  using type_t = enum {
    INT,
    LONG,
    FLOAT,
    DOUBLE,
    STRING,
    BOOL
  };
  
  // Parsing of one value of a given type into a given addres
  static void parse_value(type_t type, void* dest, char* arg_value) {
    switch (type) {
      case INT: {
        int* vi = (int*) dest;
        *vi = atoi(arg_value);
        break; }
      case LONG: {
        long* vi = (long*) dest;
        sscanf(arg_value, "%ld", vi);
        break; }
      case BOOL: {
        bool* vb = (bool*) dest;
        *vb = (atoi(arg_value) != 0);
        break; }
      case FLOAT: {
        float* vf = (float*) dest;
        *vf = (float)atof(arg_value);
        break; }
      case DOUBLE: {
        double* vf = (double*) dest;
        *vf = atof(arg_value);
        break; }
      case STRING: {
        std::string* vs = (std::string*) dest;
        *vs = std::string(arg_value);
        break; }
      default: {
        printf("not yet supported");
        exit(-1); }
    }
  }
  
  static bool parse(type_t type, std::string name, void* dest) {
    check_set();
    for (int a = 1; a < global_argc; a++) {
      if (*(global_argv[a]) != '-')
        failure();
      char* arg_name = global_argv[a] + 1;
      if (arg_name[0] == '-') {
        if (name.compare(arg_name+1) == 0) {
          *((bool*) dest) = 1;
          return true;
        }
      } else {
        a++;
        if (a >= global_argc)
          failure();
        char* arg_value = global_argv[a];
        if (name.compare(arg_name) == 0) {
          parse_value(type, dest, arg_value);
          return true;
        }
      }
    }
    return false;
  }
  
} // end namespace
  
/*---------------------------------------------------------------------*/
/* Initialization */

void set(int argc, char** argv) {
  global_argc = argc;
  global_argv = argv;
}

__attribute__((constructor)) // GCC syntax that makes __initialize run before main()
void __initialize(int argc, char **argv) {
  set(argc, argv);
}

std::string name_of_my_executable() {
  return std::string(global_argv[0]);
}
 
/*---------------------------------------------------------------------*/
/* Parsing functions */
  
template <class Item>
Item parse(std::string key) {
  Item x;
  std::cerr << "Error: item type is not supported" << std::endl;
  exit(0);
  return x;
}
  
template <>
bool parse<bool>(std::string key) {
  bool r;
  check(key, parse(BOOL, key, &r));
  return r;
}
  
template <>
int parse<int>(std::string key) {
  int r;
  check(key, parse(INT, key, &r));
  return r;
}
  
template <>
long parse<long>(std::string key) {
  long r;
  check(key, parse(LONG, key, &r));
  return r;
}

template <>
float parse<float>(std::string key) {
  float r;
  check(key, parse(FLOAT, key, &r));
  return r;
}

template <>
double parse<double>(std::string key) {
  double r;
  check(key, parse(DOUBLE, key, &r));
  return r;
}

template <>
std::string parse<std::string>(std::string key) {
  std::string r;
  check(key, parse(STRING, key, &r));
  return r;
}
  
template <class Item>
Item parse_or_default(std::string key, Item d,
                      bool expected=true) {
  Item x;
  std::cerr << "Error: item type is not supported" << std::endl;
  exit(0);
  return x;
}

template <>
bool parse_or_default(std::string key, bool d,
                      bool expected) {
  bool r;
  if (parse(BOOL, key, &r)) {
    return r;
  } else {
    print_default(key, d, expected);
    return d;
  }
}

template <>
int parse_or_default(std::string key, int d,
                      bool expected) {
  int r;
  if (parse(INT, key, &r)) {
    return r;
  } else {
    print_default(key, d, expected);
    return d;
  }
}
  
template <>
long parse_or_default(std::string key, long d,
                      bool expected) {
  long r;
  if (parse(LONG, key, &r)) {
    return r;
  } else {
    print_default(key, d, expected);
    return d;
  }
}

template <>
float parse_or_default(std::string key, float d,
                       bool expected) {
  float r;
  if (parse(FLOAT, key, &r)) {
    return r;
  } else {
    print_default(key, d, expected);
    return d;
  }
}

template <>
double parse_or_default(std::string key, double d,
                        bool expected) {
  double r;
  if (parse(DOUBLE, key, &r)) {
    return r;
  } else {
    print_default(key, d, expected);
    return d;
  }
}

template <>
std::string parse_or_default(std::string key, std::string d,
                             bool expected) {
  std::string r;
  if (parse(STRING, key, &r)) {
    return r;
  } else {
    print_default(key, d, expected);
    return d;
  }
}
  
/*---------------------------------------------------------------------*/
/* For backwards compatibility */

bool parse_bool(std::string key) {
  return parse<bool>(key);
}

int parse_int(std::string key) {
  return parse<bool>(key);
}

long parse_long(std::string key) {
  return parse<long>(key);
}

float parse_float(std::string key) {
  return parse<float>(key);
}

double parse_double(std::string key) {
  return parse<double>(key);
}

std::string parse_string(std::string key) {
  return parse<std::string>(key);
}
  
bool parse_or_default_bool(std::string key, bool d,
                           bool expected=true) {
  return parse_or_default(key, d, expected);
}

int parse_or_default_int(std::string key, int d,
                         bool expected=true) {
  return parse_or_default(key, d, expected);
}

long parse_or_default_long(std::string key, long d,
                           bool expected=true) {
  return parse_or_default(key, d, expected);
}

float parse_or_default_float(std::string key, float d,
                             bool expected=true) {
  return parse_or_default(key, d, expected);
}

double parse_or_default_double(std::string key, double d,
                               bool expected=true) {
  return parse_or_default(key, d, expected);
}

std::string parse_or_default_string(std::string key, std::string d,
                                    bool expected=true) {
  return parse_or_default(key, d, expected);
}
  
/*---------------------------------------------------------------------*/
/* Dispatcher */
  
class dispatcher {
public:
  
  using thunk_type = std::function<void()>;
  
private:
  
  std::map<std::string, thunk_type> table;
  
  void failwith(std::string key, std::string label) {
    std::cout << "Not found: -" << key << " " << label << std::endl;
    std::cout << "Valid arguments are: ";
    for (auto it = table.begin(); it != table.end(); it++) {
      std::cout << it->first << " ";
    }
    std::cout << std::endl;
    exit(1);
  }
  
public:
  
  void add(std::string label, thunk_type f) {
    table.insert(std::make_pair(label, f));
  }
  
  void dispatch(std::string key) {
    std::string label = parse_or_default<std::string>(key, "");
    auto it = table.find(label);
    if (it == table.end()) {
      failwith(key, label);
    }
    thunk_type& f = (*it).second;
    f();
  }
  
  void dispatch_or_default(std::string key, std::string d) {
    std::string label = parse_or_default<std::string>(key, "");
    auto it = table.find(label);
    if (it == table.end()) {
      auto it2 = table.find(d);
      if (it2 == table.end()) {
        failwith(key, d);
      }
      thunk_type& f = (*it2).second;
      f();
    } else {
      thunk_type& f = (*it).second;
      f();
    }
  }
  
};
  
} // end namespace
} // end namespace
