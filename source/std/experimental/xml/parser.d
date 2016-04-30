
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

/+
+   The low level XML parser.
+   Params:
+       L              = the underlying lexer type
+       preserveSpaces = whether to emit tokens for spaces between tags and whether
+                        to preserve space characters at the beginning of text contents
+/
struct Parser(L, bool preserveSpaces = false)
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
    
    bool empty()
    {
        static if (!preserveSpaces)
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
        static if (!preserveSpaces)
            lexer.dropWhile(" \r\n\t");
        
        if (lexer.empty)
            throw new EndOfStreamException();
        
        lexer.start();
        
        // text element
        if (!lexer.testAndAdvance('<'))
        {
            lexer.advanceUntil('<', false);
            next.kind = NodeType.Kind.TEXT;
            next.content = lexer.get();
        }
        
        // tag end
        else if (lexer.testAndAdvance('/'))
        {
            lexer.advanceUntil('>', true);
            next.content = lexer.get()[2..($-1)];
            next.kind = NodeType.Kind.END_TAG;
        }
        // processing instruction
        else if (lexer.testAndAdvance('?'))
        {
            int c;
            do
                lexer.advanceUntil('?', true);
            while (!lexer.testAndAdvance('>'));
            next.content = lexer.get()[2..($-2)];
            next.kind = NodeType.Kind.PROCESSING;
        }
        // tag start
        else if (!lexer.testAndAdvance('!'))
        {
            int c;
            while ((c = lexer.advanceUntilAny("\"'/>", true)) < 2)
                if (c == 0)
                    lexer.advanceUntil('"', true);
                else
                    lexer.advanceUntil('\'', true);
                    
            if (c == 2)
            {
                lexer.advanceUntil('>', true); // should be the first character after '/'
                next.content = lexer.get()[1..($-2)];
                next.kind = NodeType.Kind.EMPTY_TAG;
            }
            else
            {
                next.content = lexer.get()[1..($-1)];
                next.kind = NodeType.Kind.START_TAG;
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
                next.content = lexer.get()[9..($-3)];
                next.kind = NodeType.Kind.CDATA;
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
                next.content = lexer.get()[3..($-3)];
                next.kind = NodeType.Kind.CONDITIONAL;
            }
        }
        // comment
        else if (lexer.testAndAdvance('-'))
        {
            lexer.testAndAdvance('-'); // second '-'
            do
                lexer.advanceUntil('>', true);
            while (!fastEqual(lexer.get()[($-3)..$], "-->"));
            next.content = lexer.get()[4..($-3)];
            next.kind = NodeType.Kind.COMMENT;
        }
        // declaration or doctype
        else
        {
            int c;
            while ((c = lexer.advanceUntilAny("\"'[>", true)) < 2)
                if (c == 0)
                    lexer.advanceUntil('"', true);
                else
                    lexer.advanceUntil('\'', true);
                
            // doctype
            if (fastEqual(lexer.get()[2..9], "DOCTYPE"))
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
                                int cc;
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
                next.content = lexer.get()[9..($-1)];
                next.kind = NodeType.Kind.DOCTYPE;
            }
            else
            {
                if (c == 2)
                {
                    int cc;
                    while ((cc = lexer.advanceUntilAny("\"'>", true)) < 2)
                        if (cc == 0)
                            lexer.advanceUntil('"', true);
                        else
                            lexer.advanceUntil('\'', true);
                }
                next.content = lexer.get()[2..($-1)];
                next.kind = NodeType.Kind.DECLARATION;
            }
        }
        
        ready = true;
    }
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
    
    alias Kind = typeof(parser.front.kind);
    
    assert(parser.front.kind == Kind.PROCESSING);
    assert(parser.front.content == "xml encoding = \"utf-8\" ");
    parser.popFront();
    
    assert(parser.front.kind == Kind.START_TAG);
    assert(parser.front.content == "aaa xmlns:myns=\"something\"");
    parser.popFront();
    
    assert(parser.front.kind == Kind.START_TAG);
    assert(parser.front.content == "myns:bbb myns:att='>'");
    parser.popFront();
    
    assert(parser.front.kind == Kind.COMMENT);
    assert(parser.front.content == " lol ");
    parser.popFront();
    
    assert(parser.front.kind == Kind.TEXT);
    // use splitlines so the unittest does not depend on the newline policy of this file
    assert(parser.front.content.splitLines == ["Lots of Text!", "            On multiple lines!", "        "]);
    parser.popFront();
    
    assert(parser.front.kind == Kind.END_TAG);
    assert(parser.front.content == "myns:bbb");
    parser.popFront();
    
    assert(parser.front.kind == Kind.CDATA);
    assert(parser.front.content == " Ciaone! ");
    parser.popFront();
    
    assert(parser.front.kind == Kind.EMPTY_TAG);
    assert(parser.front.content == "ccc");
    parser.popFront();
    
    assert(parser.front.kind == Kind.END_TAG);
    assert(parser.front.content == "aaa");
    parser.popFront();
    
    assert(parser.empty);
}
