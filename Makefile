
.PHONY: help
help:
	@echo Available commands:
	@echo - benchmark: builds and benchmarks the library
	@echo - clean: deletes all binaries
	@echo - clean-random-benchmark: deletes random benchmark files
	@echo - help: shows this text
	@echo - random-benchmark: builds the library and executes random benchmarks
	@echo - test: builds and executes compliance tests
	@echo - unittest: builds and executes unittests

.PHONY: benchmark
benchmark:
	dub run -c benchmark -b release

.PHONY: clean
clean:
	dub clean
	$(RM) __test__library__
	$(RM) std-experimental-xml
	$(RM) lib*.a
	
.PHONY: clean-random-benchmark
clean-random-benchmark:
	$(RM) -rf random-benchmark

# alternative clean command - TODO: find a way to not list directories
# ls | grep -viE "^*\..*$$" | grep -vi "Makefile" | xargs -d"\n" rm -f

.PHONY: random-benchmark
random-benchmark:
	dub run -c random-benchmark -b release

.PHONY: test
test:
	dub run -c test -b debug
	
.PHONY: unittest
unittest:
	dub test -b unittest
