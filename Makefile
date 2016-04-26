
.PHONY: help
help:
	@echo Available commands:
	@echo - benchmark: builds and benchmarks the library
	@echo - clean: deletes all executables and libraries
	@echo - test: builds and executes unittests

.PHONY: benchmark
benchmark:
	dub run -c benchmark

.PHONY: clean
clean:
	dub clean
	$(RM) __test__library__
	$(RM) std-experimental-xml
	$(RM) lib*.a
	
.PHONY: test
test:
	dub test
