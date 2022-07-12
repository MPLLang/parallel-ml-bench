CPP=g++
BIN=bin

ifeq (, $(shell which jemalloc-config))
JEMALLOC =
else
JEMALLOCLD = $(shell jemalloc-config --libdir)
JEMALLOC = -L$(JEMALLOCLD) -ljemalloc
endif

CILK_COMMON_PREFIX=-fcilkplus -lcilkrts -DCILK -ldl -DPARLAY_CILK
HOMEGROWN_COMMON_PREFIX=-pthread
SCHEDULER_COMMON_PREFIX=$(HOMEGROWN_COMMON_PREFIX)

ifdef USE_HWLOC
	HWLOC_PREFIX+=-DUSE_HWLOC
endif

INCLUDE_FILES=\
	$(wildcard *.hpp *.h)
INCLUDE_DIRECTIVES=-Ipbbsbench/parlaylib/include

WARNINGS_PREFIX=-Wno-subobject-linkage -Wno-overflow -Wfatal-errors
COMMON_PREFIX=-std=c++17 -mcx16 -pthread $(WARNINGS_PREFIX) $(HWLOC_PREFIX)

OPT_PREFIX=-O3 -march=native -DNDEBUG $(COMMON_PREFIX)
DBG_PREFIX=-O0 -g -fsanitize=address,undefined $(COMMON_PREFIX)

PARDBG_PREFIX=$(DBG_PREFIX) $(SCHEDULER_COMMON_PREFIX)
SEQDBG_PREFIX=$(DBG_PREFIX)

PBBSLIBCPP_PREFIX=$(OPT_PREFIX) $(SCHEDULER_COMMON_PREFIX)
PBBSLIBCPPHG_PREFIX=$(OPT_PREFIX) $(SCHEDULER_COMMON_PREFIX)

.PHONY: bin_folder
bin_folder:
	mkdir -p $(BIN)

# Debugging binaries
# ------------------

%.pardbg.bin: %.cpp $(INCLUDE_FILES) bin_folder
	$(CPP) $(PARDBG_PREFIX) $(INCLUDE_DIRECTIVES) -o $(BIN)/$@ $<

%.seqdbg.bin: %.cpp $(INCLUDE_FILES) bin_folder
	$(CPP) $(SEQDBG_PREFIX) $(INCLUDE_DIRECTIVES) -o $(BIN)/$@ $<

# Optimized binaries
# ------------------

# %.cpp-space.bin: %.cpp $(INCLUDE_FILES) bin_folder
# 	$(CPP) $(PBBSLIBCPP_PREFIX) $(INCLUDE_DIRECTIVES) -o $(BIN)/$@ $< $(JEMALLOC)

%.cpp.bin: %.cpp $(INCLUDE_FILES) bin_folder
	$(CPP) $(PBBSLIBCPP_PREFIX) $(INCLUDE_DIRECTIVES) -o $(BIN)/$@ $< $(JEMALLOC)

# %.cppstats.bin: %.cpp $(INCLUDE_FILES) bin_folder
# 	$(CPP) $(PBBSLIBCPP_PREFIX) $(INCLUDE_DIRECTIVES) $(SCHEDULER_EXTRAS_PREFIX) -o $(BIN)/$@ $< $(JEMALLOC)

# %.cpphg.bin: %.cpp $(INCLUDE_FILES) bin_folder
# 	$(CPP) $(PBBSLIBCPPHG_PREFIX) $(INCLUDE_DIRECTIVES) -o $(BIN)/$@ $< $(JEMALLOC)


PROGRAMS=\
	primes \
	delaunay \
	nearest-nbrs

all_cpp: $(PROGRAMS:%=%.cpp.bin)

clean:
	rm -f $(BIN)/*.bin
