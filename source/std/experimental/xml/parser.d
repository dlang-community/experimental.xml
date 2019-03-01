/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements a low level XML parser.
+
+   The methods a parser should implement are documented in
+   $(LINK2 ../interfaces/isParser, `std.experimental.xml.interfaces.isParser`);
+
+   Authors:
+   Lodovico Giaretta
+
+   License:
+   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
+
+   Copyright:
+   Copyright Lodovico Giaretta 2016 --
+/

module std.experimental.xml.parser;

import std.experimental.xml.interfaces;
import std.experimental.xml.faststrings;

import std.typecons : Flag, Yes, No;

/++
+   A low level XML parser.
+
+   The methods a parser should implement are documented in
+   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`);
+
+   Params:
+       L = the underlying lexer type
+       ErrorHandler = a delegate type, used to report the impossibility to parse
+                      the file due to syntax errors
+       preserveWhitespace = if set to `Yes` (default is `No`), the parser will not remove
+       element content whitespace (i.e. the whitespace that separates tags), but will
+       report it as text
+/
struct Parser(L, ErrorHandler, Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace)
    if (isLexer!L)
{
    import std.meta : staticIndexOf;

    /++
    +   The structure returned in output from the low level parser.
    +   Represents an XML token, delimited by specific patterns, based on its kind.
    +   This delimiters are not present in the content field.
    +/
    struct XMLToken
    {
        /++ The content of the token, delimiters excluded +/
        L.CharacterType[] content;

        /++ Represents the kind of token +/
        XMLKind kind;
    }

    private L lexer;
    private bool ready, insideDTD;
    private XMLToken next;

    mixin UsesErrorHandler!ErrorHandler;

    /++ Generic constructor; forwards its arguments to the lexer constructor +/
    this(Args...)(Args args)
    {
        lexer = L(args);
    }

    alias CharacterType = L.CharacterType;

    static if (needSource!L)
    {
        alias InputType = L.InputType;

        /++
        +   See detailed documentation in
        +   $(LINK2 ../interfaces/isParser, `std.experimental.xml.interfaces.isParser`)
        +/
        void setSource(InputType input)
        {
            lexer.setSource(input);
            ready = false;
            insideDTD = false;
        }
    }

    static if (isSaveableLexer!L)
    {
        auto save()
        {
            Parser result = this;
            result.lexer = lexer.save;
            return result;
        }
    }

    private CharacterType[] fetchContent(size_t start = 0, size_t stop = 0)
    {
        return lexer.get[start..($ - stop)];
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isParser, `std.experimental.xml.interfaces.isParser`)
    +/
    bool empty()
    {
        static if (preserveWhitespace == No.preserveWhitespace)
            lexer.dropWhile(" \r\n\t");

        return !ready && lexer.empty;
    }

    /// ditto
    auto front()
    {
        if (!ready)
            fetchNext();
        return next;
    }

    /// ditto
    void popFront()
    {
        front();
        ready = false;
    }

    private void fetchNext()
    {
        if (!preserveWhitespace || insideDTD)
            lexer.dropWhile(" \r\n\t");

        assert(!lexer.empty);

        lexer.start();

        // dtd end
        if (insideDTD && lexer.testAndAdvance(']'))
        {
            lexer.dropWhile(" \r\n\t");
            if (!lexer.testAndAdvance('>'))
            {
                handler();
            }
            next.kind = XMLKind.dtdEnd;
            next.content = null;
            insideDTD = false;
        }

        // text element
        else if (!lexer.testAndAdvance('<'))
        {
            lexer.advanceUntil('<', false);
            next.kind = XMLKind.text;
            next.content = fetchContent();
        }

        // tag end
        else if (lexer.testAndAdvance('/'))
        {
            lexer.advanceUntil('>', true);
            next.content = fetchContent(2, 1);
            next.kind = XMLKind.elementEnd;
        }
        // processing instruction
        else if (lexer.testAndAdvance('?'))
        {
            do
                lexer.advanceUntil('?', true);
            while (!lexer.testAndAdvance('>'));
            next.content = fetchContent(2, 2);
            next.kind = XMLKind.processingInstruction;
        }
        // tag start
        else if (!lexer.testAndAdvance('!'))
        {
            size_t c;
            while ((c = lexer.advanceUntilAny("\"'/>", true)) < 2)
                if (c == 0)
                    lexer.advanceUntil('"', true);
                else
                    lexer.advanceUntil('\'', true);

            if (c == 2)
            {
                lexer.advanceUntil('>', true); // should be the first character after '/'
                next.content = fetchContent(1, 2);
                next.kind = XMLKind.elementEmpty;
            }
            else
            {
                next.content = fetchContent(1, 1);
                next.kind = XMLKind.elementStart;
            }
        }

        // cdata or conditional
        else if (lexer.testAndAdvance('['))
        {
            lexer.advanceUntil('[', true);
            // cdata
            if (lexer.get.length == 9 && fastEqual(lexer.get()[3..$], "CDATA["))
            {
                do
                    lexer.advanceUntil('>', true);
                while (!fastEqual(lexer.get()[($-3)..$], "]]>"));
                next.content = fetchContent(9, 3);
                next.kind = XMLKind.cdata;
            }
            // conditional
            else
            {
                int count = 1;
                do
                {
                    lexer.advanceUntilAny("[>", true);
                    if (lexer.get()[($-3)..$] == "]]>")
                        count--;
                    else if (lexer.get()[($-3)..$] == "<![")
                        count++;
                }
                while (count > 0);
                next.content = fetchContent(3, 3);
                next.kind = XMLKind.conditional;
            }
        }
        // comment
        else if (lexer.testAndAdvance('-'))
        {
            lexer.testAndAdvance('-'); // second '-'
            do
                lexer.advanceUntil('>', true);
            while (!fastEqual(lexer.get()[($-3)..$], "-->"));
            next.content = fetchContent(4, 3);
            next.kind = XMLKind.comment;
        }
        // declaration or doctype
        else
        {
            size_t c;
            while ((c = lexer.advanceUntilAny("\"'[>", true)) < 2)
                if (c == 0)
                    lexer.advanceUntil('"', true);
                else
                    lexer.advanceUntil('\'', true);

            // doctype
            if (lexer.get.length>= 9 && fastEqual(lexer.get()[2..9], "DOCTYPE"))
            {
                next.content = fetchContent(9, 1);
                if (c == 2)
                {
                    next.kind = XMLKind.dtdStart;
                    insideDTD = true;
                }
                else next.kind = XMLKind.dtdEmpty;
            }
            // declaration
            else
            {
                if (c == 2)
                {
                    size_t cc;
                    while ((cc = lexer.advanceUntilAny("\"'>", true)) < 2)
                        if (cc == 0)
                            lexer.advanceUntil('"', true);
                        else
                            lexer.advanceUntil('\'', true);
                }
                auto len = lexer.get().length;
                if (len > 8 && fastEqual(lexer.get()[2..9], "ATTLIST"))
                {
                    next.content = fetchContent(9, 1);
                    next.kind = XMLKind.attlistDecl;
                }
                else if (len > 8 && fastEqual(lexer.get()[2..9], "ELEMENT"))
                {
                    next.content = fetchContent(9, 1);
                    next.kind = XMLKind.elementDecl;
                }
                else if (len > 9 && fastEqual(lexer.get()[2..10], "NOTATION"))
                {
                    next.content = fetchContent(10, 1);
                    next.kind = XMLKind.notationDecl;
                }
                else if (len > 7 && fastEqual(lexer.get()[2..8], "ENTITY"))
                {
                    next.content = fetchContent(8, 1);
                    next.kind = XMLKind.entityDecl;
                }
                else
                {
                    next.content = fetchContent(2, 1);
                    next.kind = XMLKind.declaration;
                }
            }
        }

        ready = true;
    }
}

/++
+   Returns an instance of `Parser` from the given lexer.
+
+   Params:
+       preserveWhitespace = whether the returned `Parser` shall skip element content
+                            whitespace or return it as text nodes
+       lexer = the _lexer to build this `Parser` from
+       handler = optional error-handling delegate (if not provided, the default will
+                 assert on any XML syntax error)
+
+   Returns:
+   A `Parser` instance initialized with the given lexer
+/
auto parser(Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace, T, ErrorHandler)
           (auto ref T lexer, ErrorHandler handler = () { assert(0, "XML syntax error"); })
    if (isLexer!T)
{
    auto parser = Parser!(T, ErrorHandler, preserveWhitespace)();
    parser.errorHandler = handler;
    parser.lexer = lexer;
    return parser;
}

import std.experimental.xml.lexers;
import stdx.allocator.gc_allocator;

auto parser(Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace,
            Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer, T, Alloc, ErrorHandler)
           (auto ref T input, ref Alloc alloc, ErrorHandler handler = () { assert(0, "XML syntax error"); })
    if (!isLexer!T)
{
    auto lexer = input.lexer!reuseBuffer(alloc, handler);
    auto parser = Parser!(typeof(lexer), ErrorHandler, preserveWhitespace)();
    parser.errorHandler = handler;
    parser.lexer = lexer;
    return parser;
}

auto parser(Alloc = shared(GCAllocator), Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace,
            Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer, T, ErrorHandler)
           (auto ref T input, ErrorHandler handler = () { assert(0, "XML syntax error"); })
    if (!isLexer!T)
{
    auto lexer = input.lexer!(Alloc, reuseBuffer)(handler);
    auto parser = Parser!(typeof(lexer), ErrorHandler, preserveWhitespace)();
    parser.errorHandler = handler;
    parser.lexer = lexer;
    return parser;
}

/++
+   Instantiates a parser suitable for the given `InputType`.
+
+   This is completely equivalent to
+   ---
+   auto parser =
+        chooseLexer!(InputType, reuseBuffer)(alloc, handler)
+       .parser!(preserveWhitespace)(handler)
+   ---
+/
auto chooseParser(InputType,
                  Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace,
                  Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer,
                  Alloc, ErrorHandler)
                 (ref Alloc alloc, ErrorHandler handler)
{
    return chooseLexer!(InputType, reuseBuffer, Alloc, ErrorHandler)(alloc, handler)
          .parser!(preserveWhitespace)(handler);
}
/// ditto
auto chooseParser(InputType, Alloc = shared(GCAllocator),
                  Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace,
                  Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer, ErrorHandler)
                 (ErrorHandler handler)
    if (is(typeof(Alloc.instance)) && isSomeFunction!ErrorHandler)
{
    return chooseParser!(InputType, preserveWhitespace, reuseBuffer, Alloc, ErrorHandler)(Alloc.instance, handler);
}
/// ditto
auto chooseParser(InputType,
                  Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace,
                  Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer, Alloc)
                 (ref Alloc alloc)
    if (!isSomeFunction!Alloc)
{
    return chooseLexer!(InputType, reuseBuffer, Alloc)
                       (alloc, (){ throw new XMLException("XML syntax error"); })
          .parse!(preserveWhitespace)(handler);
}
/// ditto
auto chooseParser(InputType, Alloc = shared(GCAllocator),
                  Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace,
                  Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer)()
    if (is(typeof(Alloc.instance)))
{
    return chooseParser!(InputType, preserveWhitespace, reuseBuffer, Alloc)
                        (Alloc.instance, (){ throw new XMLException("XML syntax error"); });
}

@nogc unittest
{
    import std.experimental.xml.lexers;
    import stdx.allocator.mallocator;
    import std.string : lineSplitter;
    import std.algorithm : equal;

    string xml = q{
    <?xml encoding = "utf-8" ?>
    <aaa xmlns:myns="something">
        <myns:bbb myns:att='>'>
            <!-- lol -->
            Lots of Text!
            On multiple lines!
        </myns:bbb>
        <![CDATA[ Ciaone! ]]>
        <ccc/>
    </aaa>
    };

    auto handler = () { assert(0, "Oopss..."); };
    auto lexer = RangeLexer!(string, typeof(handler), shared(Mallocator))(Mallocator.instance);
    lexer.errorHandler = handler;
    auto parser = lexer.parser;
    assert(parser.empty);
    parser.setSource(xml);

    alias XMLKind = typeof(parser.front.kind);

    assert(parser.front.kind == XMLKind.processingInstruction);
    assert(parser.front.content == "xml encoding = \"utf-8\" ");
    parser.popFront();

    assert(parser.front.kind == XMLKind.elementStart);
    assert(parser.front.content == "aaa xmlns:myns=\"something\"");
    parser.popFront();

    assert(parser.front.kind == XMLKind.elementStart);
    assert(parser.front.content == "myns:bbb myns:att='>'");
    parser.popFront();

    assert(parser.front.kind == XMLKind.comment);
    assert(parser.front.content == " lol ");
    parser.popFront();

    assert(parser.front.kind == XMLKind.text);
    // use lineSplitter so the unittest does not depend on the newline policy of this file
    static immutable linesArr = ["Lots of Text!", "            On multiple lines!", "        "];
    assert(parser.front.content.lineSplitter.equal(linesArr));
    parser.popFront();

    assert(parser.front.kind == XMLKind.elementEnd);
    assert(parser.front.content == "myns:bbb");
    parser.popFront();

    assert(parser.front.kind == XMLKind.cdata);
    assert(parser.front.content == " Ciaone! ");
    parser.popFront();

    assert(parser.front.kind == XMLKind.elementEmpty);
    assert(parser.front.content == "ccc");
    parser.popFront();

    assert(parser.front.kind == XMLKind.elementEnd);
    assert(parser.front.content == "aaa");
    parser.popFront();

    assert(parser.empty);
}

unittest
{
    import std.experimental.xml.lexers;
    import std.algorithm : find;
    import std.string : stripRight;

    string xml = q"{
    <!DOCTYPE mydoc https://myUri.org/bla [
        <!ELEMENT myelem ANY>
        <!ENTITY   myent    "replacement text">
        <!ATTLIST myelem foo cdata #REQUIRED >
        <!NOTATION PUBLIC 'h'>
        <!FOODECL asdffdsa >
    ]>
    }";

    auto parser = xml.parser;

    alias XMLKind = typeof(parser.front.kind);

    assert(parser.front.kind == XMLKind.dtdStart);
    assert(parser.front.content == " mydoc https://myUri.org/bla ");
    parser.popFront;

    assert(parser.front.kind == XMLKind.elementDecl);
    assert(parser.front.content == " myelem ANY");
    parser.popFront;

    assert(parser.front.kind == XMLKind.entityDecl);
    assert(parser.front.content == "   myent    \"replacement text\"");
    parser.popFront;

    assert(parser.front.kind == XMLKind.attlistDecl);
    assert(parser.front.content == " myelem foo cdata #REQUIRED ");
    parser.popFront;

    assert(parser.front.kind == XMLKind.notationDecl);
    assert(parser.front.content == " PUBLIC 'h'");
    parser.popFront;

    assert(parser.front.kind == XMLKind.declaration);
    assert(parser.front.content == "FOODECL asdffdsa ");
    parser.popFront;

    assert(parser.front.kind == XMLKind.dtdEnd);
    assert(!parser.front.content);
    parser.popFront;

    assert(parser.empty);
}