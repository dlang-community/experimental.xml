/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements the low level XML parser.
+   For documentation, see experimental.xml.interfaces.
+/

module std.experimental.xml.parser;

import std.experimental.xml.interfaces;
import std.experimental.xml.faststrings;

import core.exception;

class EndOfStreamException: Exception
{
    this(string file = __FILE__, int line = __LINE__) @nogc
    {
        super("End of XML stream", file, line);
    }
}

class UnexpectedEndOfStreamException: Exception
{
    this(string file = __FILE__, int line = __LINE__) @nogc
    {
        super("Unexpected end of XML stream while parsing", file, line);
    }
}

import std.experimental.allocator.gc_allocator;

enum ParserOptions
{
    PreserveSpaces,
    CopyStrings,
    AutomaticDeallocation
}

/+
+   The low level XML parser.
+   Params:
+       L              = the underlying lexer type
+/
struct Parser(L, Alloc = shared(GCAllocator), options...)
    if (isLexer!L)
{
    import std.meta: staticIndexOf;

    private alias NodeType = XMLToken!(L.CharacterType);

    private L lexer;
    private bool ready;
    private NodeType next;
    
    alias InputType = L.InputType;
    alias CharacterType = L.CharacterType;
    
    static if (is(typeof(Alloc.instance)))
        Alloc* allocator = &(Alloc.instance);
    else
        Alloc* allocator;

    /++ Generic constructor; forwards its arguments to the lexer constructor +/
    this(Args...)(Args args)
        if (!is(Args[0] == Alloc*) && !is(Args[0] == Alloc))
    {
        lexer = L(args);
    }
    /// ditto
    this(Args...)(Alloc* alloc, Args args)
    {
        allocator = alloc;
        lexer = L(args);
    }
    /// ditto
    this(Args...)(ref Alloc alloc, Args args)
    {
        allocator = &alloc;
        lexer = L(args);
    }
    
    void setSource(InputType input)
    {
        lexer.setSource(input);
        ready = false;
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
        static if (staticIndexOf!(options, ParserOptions.CopyStrings) >= 0)
        {
            import std.experimental.allocator;
            import core.stdc.string: memcpy;
            
            auto s = lexer.get;
            auto len = s.length - stop - start;
            auto copy = allocator.allocate(len*CharacterType.sizeof);
            memcpy(copy.ptr, s.ptr + start, len);
            lexer.deallocateLast;
            return cast(CharacterType[])copy;
        }
        else
            return lexer.get[start..($ - stop)];
    }
    
    void deallocateLast()
    {
        static if (staticIndexOf!(options, ParserOptions.CopyStrings) >= 0)
            allocator.deallocate(cast(void[]) next.content);
        else
            lexer.deallocateLast;
    }
    
    void throwException(T)()
    {
        import std.experimental.allocator;
        throw make!(T, Alloc)(*allocator);
    }
    
    bool empty()
    {
        static if (staticIndexOf!(options, ParserOptions.PreserveSpaces) < 0)
            lexer.dropWhile(" \r\n\t");
            
        return !ready && lexer.empty;
    }
    
    auto front()
    {
        if (!ready)
            try
            {
                fetchNext();
            }
            catch (AssertError exc)
            {
                if (lexer.empty)
                    throwException!UnexpectedEndOfStreamException;
                else
                    throw exc;
            }
        return next;
    }
    
    void popFront()
    {
        front();
        ready = false;
        static if (staticIndexOf!(options, ParserOptions.AutomaticDeallocation))
            deallocateLast;
    }
    
    private void fetchNext()
    {
        static if (staticIndexOf!(options, ParserOptions.PreserveSpaces) < 0)
            lexer.dropWhile(" \r\n\t");
        
        if (lexer.empty)
            throwException!EndOfStreamException;
        
        lexer.start();
        
        // text element
        if (!lexer.testAndAdvance('<'))
        {
            lexer.advanceUntil('<', false);
            next.kind = XMLKind.TEXT;
            next.content = fetchContent();
        }
        
        // tag end
        else if (lexer.testAndAdvance('/'))
        {
            lexer.advanceUntil('>', true);
            next.content = fetchContent(2, 1);
            next.kind = XMLKind.ELEMENT_END;
        }
        // processing instruction
        else if (lexer.testAndAdvance('?'))
        {
            size_t c;
            do
                lexer.advanceUntil('?', true);
            while (!lexer.testAndAdvance('>'));
            next.content = fetchContent(2, 2);
            next.kind = XMLKind.PROCESSING_INSTRUCTION;
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
                next.kind = XMLKind.ELEMENT_EMPTY;
            }
            else
            {
                next.content = fetchContent(1, 1);
                next.kind = XMLKind.ELEMENT_START;
            }
        }
        
        // cdata or conditional
        else if (lexer.testAndAdvance('['))
        {
            lexer.advanceUntil('[', true);
            // cdata
            if (fastEqual(lexer.get()[3..$], "CDATA["))
            {
                do
                    lexer.advanceUntil('>', true);
                while (!fastEqual(lexer.get()[($-3)..$], "]]>"));
                next.content = fetchContent(9, 3);
                next.kind = XMLKind.CDATA;
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
                next.kind = XMLKind.CONDITIONAL;
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
            next.kind = XMLKind.COMMENT;
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
                // inline dtd
                if (c == 2)
                {
                    while (lexer.advanceUntilAny("<]", true) == 0)
                        // processing instruction
                        if (lexer.testAndAdvance('?'))
                        {
                            do
                                lexer.advanceUntil('?', true);
                            while (!lexer.testAndAdvance('>'));
                        }
                        // declaration or comment
                        else if (lexer.testAndAdvance('!'))
                        {
                            // comment
                            if (lexer.testAndAdvance('-'))
                            {
                                do
                                    lexer.advanceUntil('>', true);
                                while (!fastEqual(lexer.get()[($-3)..$], "-->"));
                            }
                            // declaration
                            else
                            {
                                size_t cc;
                                while ((cc = lexer.advanceUntilAny("\"'>", true)) < 2)
                                    if (cc == 0)
                                        lexer.advanceUntil('"', true);
                                    else
                                        lexer.advanceUntil('\'', true);
                            }
                        }
                        // if you're here, something is wrong...
                        else assert(0);
                    lexer.advanceUntil('>', true);
                }
                next.content = fetchContent(9, 1);
                next.kind = XMLKind.DOCTYPE;
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
                    next.kind = XMLKind.ATTLIST_DECL;
                }
                else if (len > 8 && fastEqual(lexer.get()[2..9], "ELEMENT"))
                {
                    next.content = fetchContent(9, 1);
                    next.kind = XMLKind.ELEMENT_DECL;
                }
                else if (len > 9 && fastEqual(lexer.get()[2..10], "NOTATION"))
                {
                    next.content = fetchContent(10, 1);
                    next.kind = XMLKind.NOTATION_DECL;
                }
                else if (len > 7 && fastEqual(lexer.get()[2..8], "ENTITY"))
                {
                    next.content = fetchContent(8, 1);
                    next.kind = XMLKind.ENTITY_DECL;
                }
                else
                {
                    next.content = fetchContent(2, 1);
                    next.kind = XMLKind.DECLARATION;
                }
            }
        }
        
        ready = true;
    }
}

auto parse(T)(auto ref T input)
    if (isLexer!(T.Type))
{
    struct Chain
    {
        alias Type = Parser!T;
        auto finalize()
        {
            return Type(input.finalize(), false, Type.NodeType);
        }
    }
    return Chain();
}

@nogc unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.allocator.mallocator;
    import std.string: lineSplitter;
    import std.algorithm: equal;
    
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
    
    auto alloc = Mallocator.instance;
    auto parser = Parser!(SliceLexer!(string, shared(Mallocator)), shared(Mallocator), ParserOptions.CopyStrings)(alloc, alloc);
    parser.setSource(xml);
    
    alias XMLKind = typeof(parser.front.kind);
    
    assert(parser.front.kind == XMLKind.PROCESSING_INSTRUCTION);
    assert(parser.front.content == "xml encoding = \"utf-8\" ");
    parser.popFront();
    
    assert(parser.front.kind == XMLKind.ELEMENT_START);
    assert(parser.front.content == "aaa xmlns:myns=\"something\"");
    parser.popFront();
    
    assert(parser.front.kind == XMLKind.ELEMENT_START);
    assert(parser.front.content == "myns:bbb myns:att='>'");
    parser.popFront();
    
    assert(parser.front.kind == XMLKind.COMMENT);
    assert(parser.front.content == " lol ");
    parser.popFront();
    
    assert(parser.front.kind == XMLKind.TEXT);
    // use lineSplitter so the unittest does not depend on the newline policy of this file
    static immutable linesArr = ["Lots of Text!", "            On multiple lines!", "        "];
    assert(parser.front.content.lineSplitter.equal(linesArr));
    parser.popFront();
    
    assert(parser.front.kind == XMLKind.ELEMENT_END);
    assert(parser.front.content == "myns:bbb");
    parser.popFront();
    
    assert(parser.front.kind == XMLKind.CDATA);
    assert(parser.front.content == " Ciaone! ");
    parser.popFront();
    
    assert(parser.front.kind == XMLKind.ELEMENT_EMPTY);
    assert(parser.front.content == "ccc");
    parser.popFront();
    
    assert(parser.front.kind == XMLKind.ELEMENT_END);
    assert(parser.front.content == "aaa");
    parser.popFront();
    
    assert(parser.empty);
}

unittest
{
    import std.experimental.xml.lexers;
    import std.algorithm: find;
    import std.string: stripRight;
    
    string xml = q{
    <!DOCTYPE mydoc https://myUri.org/bla [
        <!ELEMENT myelem ANY>
        <!ENTITY myent "replacement text">
        <!ATTLIST myelem foo CDATA #REQUIRED>
    ]>
    };
    
    auto parser = Parser!(SliceLexer!string)();
    parser.setSource(xml);
    
    alias XMLKind = typeof(parser.front.kind);
    
    assert(parser.front.kind == XMLKind.DOCTYPE);
    assert(parser.front.content == xml.find("<!DOCTYPE").stripRight[9..($-1)]);
    parser.popFront;
    assert(parser.empty);
}

unittest
{
    import std.experimental.xml.lexers;
    import std.algorithm: find;
    import std.string: stripRight;
    
    string xml = q{
        <!ELEMENT myelem ANY>
        <!ENTITY   myent    "replacement text">
        <!ATTLIST myelem foo CDATA #REQUIRED >
        <!NOTATION PUBLIC 'h'>
        <!FOODECL asdffdsa >
    };
    
    auto parser = Parser!(SliceLexer!string)();
    parser.setSource(xml);
    
    alias XMLKind = typeof(parser.front.kind);
    
    assert(parser.front.kind == XMLKind.ELEMENT_DECL);
    assert(parser.front.content == " myelem ANY");
    parser.popFront;
    
    assert(parser.front.kind == XMLKind.ENTITY_DECL);
    assert(parser.front.content == "   myent    \"replacement text\"");
    parser.popFront;
    
    assert(parser.front.kind == XMLKind.ATTLIST_DECL);
    assert(parser.front.content == " myelem foo CDATA #REQUIRED ");
    parser.popFront;
    
    assert(parser.front.kind == XMLKind.NOTATION_DECL);
    assert(parser.front.content == " PUBLIC 'h'");
    parser.popFront;
    
    assert(parser.front.kind == XMLKind.DECLARATION);
    assert(parser.front.content == "FOODECL asdffdsa ");
    parser.popFront;
    
    assert(parser.empty);
}