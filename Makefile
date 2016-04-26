
.PHONY: help
help:
	@echo Available commands: clean test

.PHONY: test
test:
	dub test

.PHONY: clean
clean:
	dub clean
	$(RM) __test__library__
	$(RM) *.a
