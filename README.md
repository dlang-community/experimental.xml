
# std.experimental.xml (GSoC 2016) [![Build Status](https://travis-ci.org/lodo1995/experimental.xml.svg?branch=master)](https://travis-ci.org/lodo1995/experimental.xml)

## About
This project aims to become a substitution for the current std.xml in Phobos.  
It will provide various APIs to parse, validate and output XML documents.  
It is still in its early development, and this document describes only currently
implemented features.  
It is being developed by Lodovico Giaretta as a project for Google Summer of Code 2016.

## Implementation status
Four lexers, the low-level parser and the cursor API are currently usable (and are
in fact used internally to automate testing).  
Work is steadily proceeding.

## Architectural overview
The API is designed for modularity, with many pluggable and customizable components.  
Below is the description of the components that are already implemented.

### The Lexers
They are used to abstract the input type from subsequent components, providing a
uniform API, with operations to advance the input and retrieve it. They are not
XML-specific, but their API is specifically designed for the needs of [the parser](#the-parser).

Currently, these lexers are available, in descending order of performance:

- the `SliceLexer` accepts as input a single slice; it's the fastest lexer, perfect
for small inputs, but very memory-demanding for big ones;
- the `BufferedLexer` accepts an `InputRange` of slices, representing susequent
chunks of the input; it's the optimal choice for big files and for other data that
naturally comes in chunks (e.g. network packets);
- the `ForwardLexer` and `RangeLexer` work with any `ForwardRange` or `InputRange` 
respectively; the fact that they can't use slices means that they are way slower that
the first two lexers; they should only be used as fallback for input sources that do
not allow compound reads.

### The Parser
It's a low-level components that tokenizes the input into tags and text. It applies
as few assumptions as possible, so that it may be reused for languages that resemble
XML but are not fully compatible with it. It does not do any well-formedness check.

### The Cursor
It's the first almost-high-level API directly usable in user code. It reads the XML
top-down, providing methods to query the current node for its properties and to advance
to its first child, its next sibling or the end of its parent.

### The Validating Cursor
It's a wrapper around a [Cursor](#the-cursor), with hooks to perform various validations
while advancing in the document.  
The validations are specified as template parameters to the validating cursor, for easy
customization.

### The SAX Parser
Built on top of a [Cursor](#the-cursor), it reads the entire file, notifying a custom
handler of all parsing events (i.e. of all nodes found during parsing).

### The DOM
This library contains a (still unfinished) implementation of the Document Object Model Level 3
specification. The goals of this implementation are:

- striving to be fully compliant to the specification, while adding more idiomatic alternatives
whenever useful (e.g.: the spec doesn't use enums, but plain integer constants; this library
provides both, one for compatibility and the other to match D idioms);
- striving to avoid garbage collection, not because the GC is bad (it is not!), but because this
library should be usable even in applications that cannot afford a GC (e.g.: real-time).

### The Fluent Interface
`package.d` contains some fluent wrappers for building parsing chains out of the various components

```d
    auto sax =
         withInput(myInput)
        .withParserOptions!(ParserOptions.CopyStrings)
        .withCursorOptions!(XMLCursorOptions.DontConflateCDATA)
        .asSAXParser(myHandler);
```

Which is way better than direct use of the types shown below

```d
    auto sax = SAXParser!(XMLCursor!(Parser!(SliceLexer!(typeof(myInput)), ParserOptions.CopyStrings), XMLCursorOptions.DontConflateCDATA), typeof(myHandler));
    sax.handler = myHandler;
    sax.setSource(myInput);
```

### The legacy API
It's a re-implementation of the deprecated `std.xml` module, based on [the new backend](#the-parser).  
It is provided to ease the transition. Also, this implementation should be a bit faster.

### More is Coming
Other high level APIs are currently under implementation (e.g. DOM), while others will
be implemented in the near future (e.g. an event-based parser).
