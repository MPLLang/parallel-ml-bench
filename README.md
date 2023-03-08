# parallel-ml-bench
This folder contains two
two benchmark suites for  evaluating the Parallel ML  [`mpl`](https://github.com/MPLLang/mpl) compiler.
The first suite, which we call the `ML suite`, contains 26 benchmarks
that are written in MPL. The goal of this suite is to compare the performance of MPL to MLton,
a sequential compiler for Standard ML.
The second suite, which we call the `Cross Language suite`, contains implementations of
eight benchmarks in four languages (other than MPL) : C++, Go, Java, and Multicore OCaml.
Its goal is to show that MPL is can compete with/beat these languages.

## ML suite

Among the 26 benchmarks in this suite,
thirteen of these are highly concurrent and entangled.
These implement sophisticated parallel algorithms for
- quantum circuit synthesis,
- delaunay triangulation,
- various graph analyses, including reachability/connectivity, $O(k)$-spanner, low-diameter decomposition
boundaries, etc., and
- deduplication via concurrent hashing.

Some of these benchmarks---such as the quantum synthesis and delaunay
triangulation---are complex and have taken multiple person-months of
work (each) to implement.
In addition, the entangled benchmarks include synthetic benchmarks that operate on
concurrent data structures by mixing parallelizable work with updates
and queries on the shared data structure(s).

The other half of the benchmarks are from
various problem domains, including graphs, text processing, digital audio processing,
image analysis and manipulation, numerical algorithms, computational
geometry, and others. These are ported to MPL from existing state-of-the-art
parallel C/C++ benchmark suites and libraries including
[PBBS](https://github.com/cmuparlay/pbbsbench),
[ParlayLib](https://github.com/cmuparlay/parlaylib),
[Ligra](https://github.com/jshun/ligra), and
[PAM](https://github.com/cmuparlay/PAM).


Please see also [`mpllib`](https://github.com/MPLLang/mpllib), which
is a library of key data structures and algorithms used throughout the MPL
benchmarks.

## Cross Language suite
This suite contains the implementations of
eight benchmarks in four languages (other than \mplcc{}) : C++, Go, Java, and
Multicore OCaml.
The C++ benchmarks come from
PBBS and ParlayLib.
We ported these to Go, Java, and OCaml, while re-using existing Java
implementations of two benchmarks.
We selected these benchmarks for diversity (covering both disentanglement
and entanglement, as well as both memory- and compute-intensive benchmarks),
and for ease of implementation, as it takes significant work to implement each
benchmark in multiple languages.

## Command Line Arguments for each language and its benchmarks
For each language and its benchmark,
we provide a template command that can be used
to run it with the appropriate inputs on the desired number of cores.
<!--  -->

In the `run-cross-small` folder, there is a JSON file for each language
which provides a template for running programs in that language
and also provides the benchmark-specific arguments for the experiments.
In the field "templates" of the JSON file,
there is a template field which shows how you can run a benchmark with some arguments.
In the field "specs", an array of entries specifies
the arguments (under the field `args`) for each benchmark.

You can pass any of these files to `scripts/gencmds` which produces "rows" of key-value
pairs, where each row describes one experiment. Examples of keys include
"config", "tag", etc. The config is the name of compiler configuration to
use, the tag is a unique name for each benchmark, etc.
As an example, if you run `./scripts/gencmds run-cross-small/cpp-exp.json` you will see
the commands for running the benchmarks.


## Requirements

Machine: Linux x86_64 multicore

Software requirements:
  * GCC version 9 (or later)
  * MLton version [20210117](https://github.com/MLton/mlton/releases/tag/on-20210117-release)
  * [mpl-switch](https://github.com/MPLLang/mpl-switch)
  * [smlpkg](https://github.com/diku-dk/smlpkg)
  * [jq](https://stedolan.github.io/jq/)
  * [numactl](https://github.com/numactl/numactl) (for C++, Java, Go experiments)
  * OCaml experiments only:
    - OCaml version `5.0.0+trunk`
    - [`opam`](https://github.com/ocaml/opam) version `2.1.0`
    - [`domainslib`](https://github.com/ocaml-multicore/domainslib) version `0.4.2`
    - [`dune`](https://github.com/ocaml/dune)
  * Java experiments only:
    - Java version 11
  * Go experiments only:
    - Go version 1.18




## References

[<a name="rmab16">1</a>]
[Hierarchical Memory Management for Parallel Programs](http://cs.iit.edu/~smuller/papers/icfp16-preprint.pdf).
Ram Raghunathan, Stefan K. Muller, Umut A. Acar, and Guy Blelloch.
ICFP 2016.

[<a name="gwraf18">2</a>]
[Hierarchical Memory Management for Mutable State](http://www.cs.cmu.edu/~swestric/18/ppopp.pdf).
Adrien Guatto, Sam Westrick, Ram Raghunathan, Umut Acar, and Matthew Fluet.
PPoPP 2018.

[<a name="wyfa20">3</a>]
[Disentanglement in Nested-Parallel Programs](http://www.cs.cmu.edu/~swestric/20/popl-disentangled.pdf).
Sam Westrick, Rohan Yadav, Matthew Fluet, and Umut A. Acar.
POPL 2020.

[<a name="awa21">4</a>]
[Provably Space-Efficient Parallel Functional Programming](http://www.cs.cmu.edu/~swestric/21/popl.pdf).
Jatin Arora, Sam Westrick, and Umut A. Acar.
POPL 2021.
