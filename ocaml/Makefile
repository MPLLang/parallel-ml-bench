# apparently .NOTPARALLEL overrides passing -j at command-line
# (for all targets in the makefile??)
# this is necessary here because dune is not safe for parallelism
#
# why is make awful
.NOTPARALLEL:

%.ocaml.bin:
	mkdir -p bin
	dune build ./$*.exe && cp _build/default/$*.exe bin/$@ && chmod a+w bin/$@
