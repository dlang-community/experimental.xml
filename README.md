
# std.experimental.xml (GSoC 2016) [![Build Status](https://travis-ci.org/lodo1995/experimental.xml.svg?branch=master)](https://travis-ci.org/lodo1995/experimental.xml)

## About
This project aims to become a substitution for the current std.xml in Phobos.
It will provide various APIs to parse, validate and output XML documents.
It is still in its early development, and this document describes only currently
implemented features.

## Implementation status
Two lexers, the low-level parser and the cursor API are currently usable (and are
in fact used internally to automate testing).
Work is steadily proceeding.

## Architectural overview
The API is designed for modularity.
Parsing is divided in various stages:

- a lexer abstracts the input type (InputRange, string, file) from subsequent
components;
- a low-level parser tokenizes the input from the lexer into tags and text,
applying as few assumptions as possible, so that it can be reused for formats
that resemble XML without being fully compatible with it;
- a cursor API represents the first high-level facility of the library; it allows
to advance in the document structure, querying nodes for their properties and
skipping them when not needed;
- a validating cursor wraps a cursor, performing validations while advancing in
the structure; validations are plugged-in at compilation time;
- more higher-level API (e.g. DOM building) will be implemented as soon as possible.
