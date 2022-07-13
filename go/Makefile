bindir: phony
	mkdir -p bin

%.go.bin: bin
	(cd $* && go build)
	mv $*/main bin/$*.go.bin

.PHONY: phony
phony:
