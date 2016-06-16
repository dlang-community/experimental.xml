
/++
+   This module implements the low level XML parser.
+   For documentation, see experimental.xml.interfaces.
+/

module std.experimental.xml.parser;

import std.experimental.xml.interfaces;
import std.experimental.xml.faststrings;

import core.exception;
import std.algorithm: canFind;

class EndOfStreamException: Exception
{
    this(string file = __FILE__, int line = __LINE__)
    {
        super("End of XML stream", file, line);
    }
}

class UnexpectedEndOfStreamException: Exception
{
    this(string file = __FILE__, int line = __LINE__)
    {
        super("Unexpected end of XML stream while parsing", file, line);
    }
}

enum ParserOptions
{
    PreserveSpaces,
    CopyStrings,
}

/+
+   The low level XML parser.
+   Params:
+       L              = the underlying lexer type
+/
struct Parser(L, ParserOptions[] options = [])
    if (isLexer!L)
{
    private alias NodeType = XMLToken!(L.CharacterType);

    private L lexer;
    private bool ready;
    private NodeType next;
    
    alias InputType = L.InputType;
    alias CharacterType = L.CharacterType;

    void setSource(InputType input)
    {
        lexer.setSource(input);
        ready = false;
    }
    
    static if (isSaveableLexer!L)
    {
        auto save() const
        {
            Parser result;
            result.lexer = lexer.save;
            result.ready = ready;
            result.next = next;
            return result;
        }
    }
    
    private CharacterType[] fetchContent(size_t start = 0, size_t stop = 0)
    {
        static if (options.canFind(ParserOptions.CopyStrings))
            return lexer.get[start..($ - stop)].idup;
        else
            return lexer.get[start..($ - stop)];
    }
    
    bool empty()
    {
        static if (!options.canFind(ParserOptions.PreserveSpaces))
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
                    throw new UnexpectedEndOfStreamException();
                else
                    throw exc;
            }
        return next;
    }
    
    void popFront()
    {
        front();
        ready = false;
    }
    
    private void fetchNext()
    {
        static if (!options.canFind(ParserOptions.PreserveSpaces))
            lexer.dropWhile(" \r\n\t");
        
        if (lexer.empty)
            throw new EndOfStreamException();
        
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
                        // entity, notation, attlist or comment
                        else if (lexer.testAndAdvance('!'))
                        {
                            if (lexer.testAndAdvance('-'))
                            {
                                do
                                    lexer.advanceUntil('>', true);
                                while (!fastEqual(lexer.get()[($-3)..$], "-->"));
                            }
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
                next.content = fetchContent(2, 1);
                next.kind = XMLKind.DECLARATION;
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

unittest
{
    import std.experimental.xml.lexers;
    import std.string: splitLines;
    
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
    
    auto parser = Parser!(SliceLexer!string)();
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
    // use splitlines so the unittest does not depend on the newline policy of this file
    assert(parser.front.content.splitLines == ["Lots of Text!", "            On multiple lines!", "        "]);
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
