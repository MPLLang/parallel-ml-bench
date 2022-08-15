bindir: phony
	mkdir -p bin

%.go.bin: bindir
	(cd $* && go build)
	mv $*/mymain bin/$*.go.bin

.PHONY: phony
phony:
