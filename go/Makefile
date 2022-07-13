bindir: phony
	mkdir -p bin

%.go.bin: bindir
	(cd $* && go build)
	mv $*/main bin/$*.go.bin

.PHONY: phony
phony:
