# parallel-ml-bench
Parallel ML benchmark suite for the [`mpl`](https://github.com/MPLLang/mpl)
compiler.

## Requirements

Machine: Linux x86_64 multicore

Software requirements:
  * GCC version 9 (or later)
  * MLton version [20210117](https://github.com/MLton/mlton/releases/tag/on-20210117-release)
  * [mpl-switch](https://github.com/MPLLang/mpl-switch)
  * [smlpkg](https://github.com/diku-dk/smlpkg)
  * [jq](https://stedolan.github.io/jq/)
  * C++ experiments only:
    - [numactl](https://github.com/numactl/numactl)
  * OCaml experiments only:
    - OCaml version `5.0.0+trunk`
    - [`opam`](https://github.com/ocaml/opam) version `2.1.0`
    - [`domainslib`](https://github.com/ocaml-multicore/domainslib) version `0.4.2`
    - [`dune`](https://github.com/ocaml/dune)

## Setup

First clone the repository:
```
$ git clone https://github.com/MPLLang/parallel-ml-bench
$ cd parallel-ml-bench
```

Then, run the init script. This should take approximately 15 minutes. It
installs all necessary  versions of `mpl` and generates inputs. Note that
the generated inputs require approximately 5GB of disk space.
```
$ ./init
```

## Run experiments

After completing the setup (described above), you can run all of the
experiments by passing a comma-separated list of processors to the `run`
script.

For example, here we run on 1, 4, and 8 processors:
```
$ ./run --procs 1,4,8
```

This command begins by compiling all of the benchmarks, and then runs each
one-by-one. **This will take a long time.** Depending on how many processors
you use, it could take multiple hours.

A progress indicator is printed at the beginning of each run which shows how
many commands are left to run. For example, `[5/100]` means that this is the
5th benchmark out of 100 total benchmarks to run.

Results are written to a timestamped file in the `results/` directory. The
timestamp format is `YYMMDD-HHMMSS`. Each line of the results file is a
JSON object with the parameters and results from that run.

You may terminate the `run` script early with `Ctrl-C`. All results obtained
so far will still be available in the results file.

## TODO

Infrastructure and benchmarks
  * [x] update inputs (need words256, input graphs, etc.)
  * [ ] report script (speedup plots, summary table, etc.)
  * [ ] benchmarks documentation
  * [x] MPL: infrastructure
  * [x] MPL: benchmarks
  * [x] C++: infrastructure
  * [ ] C++: **more benchmarks**
  * [ ] Java: infrastructure
  * [ ] Java: benchmarks
  * [x] OCaml: infrastructure
  * [ ] OCaml: **more benchmarks**
  * [ ] Go: infrastructure
  * [ ] Go: benchmarks

Performance optimization
  * [ ] Try z-sort for nearest neighbors. Would this improve performance
  for neighbors component of Delaunay, too?
  * [ ] Compare direction-optimizing BFS with C++ Ligra
  * [ ] Check delayed-seq performance vs hand-optimized for delayed-seq
  benchmarks
