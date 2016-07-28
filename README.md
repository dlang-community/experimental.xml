
[![Build Status](https://travis-ci.org/lodo1995/experimental.xml.svg?branch=master)](https://travis-ci.org/lodo1995/experimental.xml)
[![codecov](https://codecov.io/gh/lodo1995/experimental.xml/branch/master/graph/badge.svg)](https://codecov.io/gh/lodo1995/experimental.xml)

# std.experimental.xml (GSoC 2016)

## About
This project aims to become a substitution for the current std.xml in Phobos.  
It will provide various APIs to parse, validate and output XML documents.  
It is still in its early development, and this document describes only currently
implemented features.  
It is being developed by Lodovico Giaretta as a project for Google Summer of Code 2016.

## Implementation status
Most features are useable: the lexers, parser, cursor, SAX parser, and writer are
quite stable and used internally for testing purposes.
The DOM Level 3 implementation and the validation layer are still a work in progress.

## Documentation
The documentation automatically generated from the source is available [here](https://lodo1995.github.io/experimental.xml).
Be aware that most functions and types are still undocumented and some comments may
be outdated wrt. the implementation.