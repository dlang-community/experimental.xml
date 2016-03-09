
module experimental.xml.lexer;

import interfaces;

import core.exception;
import std.array;
import std.range.primitives;
import std.string;
import std.traits;

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

/*
*   SLICE LEXER IMPLEMENTATION
*   Pros: it should be fast and not require allocations
*   Cons: it requires the input to be entirely loaded in memory
*/

struct SliceLexer(T)
{
    alias CharacterType = ElementEncodingType!T;
    alias InputType = T;
    
    T input;
    size_t pos;
    size_t begin;
    
    void setSource(T input)
    {
        this.input = input;
        pos = 0;
    }
    
    static if(isForwardRange!T)
    {
        auto save() const
        {
            SliceLexer result;
            result.input = input;
            result.pos = pos;
            return result;
        }
    }
    
    auto empty() const
    {
        return pos >= input.length;
    }
    
    void start()
    {
        begin = pos;
    }
    
    CharacterType[] get() const
    {
        return input[begin..pos];
    }
    
    void dropWhile(string s)
    {
        while(pos < input.length && s.indexOf(input[pos]) != -1)
            pos++;
    }
    
    bool testAndAdvance(char c)
    {
        if(input[pos] == c)
        {
            pos++;
            return true;
        }
        return false;
    }
    
    void advanceUntil(char c, bool included)
    {
        while(input[pos] != c)
            pos++;
        if(included)
            pos++;
    }
    
    int advanceUntilEither(char c1, char c2)
    {
        while(input[pos] != c1 && input[pos] != c2)
            pos++;
        
        if(input[pos++] == c1)
            return 0;
        else
            return 1;
    }
    
    int advanceUntilAny(char c1, char c2, char c3)
    {
        while(input[pos] != c1 && input[pos] != c2 && input[pos] != c3)
            pos++;
        
        if(input[pos] == c1)
        {
            pos++;
            return 0;
        }
        else if(input[pos++] == c2)
            return 1;
        else
            return 2;
    }
}

/*
*   RANGE LEXER IMPLEMENTATION
*   Pros: works with any InputRange, loads the input lazily
*   Cons: does lots of memory allocations and slow appends
*/

struct RangeLexer(T)
    if(isInputRange!T)
{
    alias CharacterType = ElementEncodingType!T;
    alias InputType = T;
    
    T input;
    Appender!(CharacterType[]) app;
    
    void setSource(T input)
    {
        this.input = input;
    }
    
    static if(isForwardRange!T)
    {
        auto save() const
        {
            RangeLexer result;
            result.input = input.save();
            return result;
        }
    }
    
    bool empty() const
    {
        return input.empty;
    }
    
    void start()
    {
        app = appender!(CharacterType[])();
    }
    
    CharacterType[] get() const
    {
        return app.data;
    }
    
    void dropWhile(string s)
<<<<<<< HEAD
    {
        while(!input.empty && s.indexOf(input.front) != -1)
            input.popFront();
    }
    
    bool testAndAdvance(char c)
    {
=======
    {
        while(!input.empty && s.indexOf(input.front) != -1)
            input.popFront();
    }
    
    bool testAndAdvance(char c)
    {
>>>>>>> df63fa6855a68852547ee25769cf812a9855ce30
        if(input.front == c)
        {
            app.put(input.front);
            input.popFront();
            return true;
        }
        return false;
    }
    
    void advanceUntil(char c, bool included)
    {
        while(input.front != c)
        {
            app.put(input.front);
            input.popFront();
        }
        if(included)
        {
            app.put(input.front);
            input.popFront();
        }
    }
    
    int advanceUntilEither(char c1, char c2)
    {
        do
        {
            app.put(input.front);
            input.popFront();
        } while(app.data[$-1] != c1 && app.data[$-1] != c2);
        
        if(app.data[$-1] == c1)
            return 0;
        else
            return 1;
    }
    
    int advanceUntilAny(char c1, char c2, char c3)
    {
        do
        {
            app.put(input.front);
            input.popFront();
        } while(app.data[$-1] != c1 && app.data[$-1] != c2 && app.data[$-1] != c3);
        
        if(app.data[$-1] == c1)
            return 0;
        else if(app.data[$-1] == c2)
            return 1;
        else
            return 2;
    }
}

/*
*   LOW LEVEL PARSER IMPLEMENTATION
*/

struct Parser(L, bool preserveSpaces = false)
    if(isLexer!L)
{
    private alias NodeType = LowLevelNode!(L.CharacterType);

    private L lexer;
    private bool ready;
    private NodeType next;
    
    alias InputType = L.InputType;

    void setSource(InputType input)
    {
        lexer.setSource(input);
    }
    
    static if(isSaveableLexer!L)
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
        static if(!preserveSpaces)
            lexer.dropWhile(" \r\n\t");
            
        return lexer.empty;
    }
    
    auto front()
    {
        if(!ready)
            try
            {
                fetchNext();
            }
            catch(AssertError exc)
            {
                if(lexer.empty)
                    throw new UnexpectedEndOfStreamException();
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
        static if(!preserveSpaces)
            lexer.dropWhile(" \r\n\t");
            
        if(lexer.empty)
            throw new EndOfStreamException();
        
        lexer.start();
        
        // text element
        if(!lexer.testAndAdvance('<'))
        {
            lexer.advanceUntil('<', false);
            next.content = lexer.get();
            next.kind = NodeType.Kind.TEXT;
        }
        
        // tag end
        else if(lexer.testAndAdvance('/'))
        {
            lexer.advanceUntil('>', true);
            next.content = lexer.get()[2..($-1)];
            next.kind = NodeType.Kind.END_TAG;
        }
        // processing instruction
        else if(lexer.testAndAdvance('?'))
        {
            do
                while(lexer.advanceUntilEither('"', '?') == 0)
                    lexer.advanceUntil('"', true);
            while(!lexer.testAndAdvance('>'));
            
            next.content = lexer.get()[2..($-2)];
            next.kind = NodeType.Kind.PROCESSING;
        }
        // tag start
        else if(!lexer.testAndAdvance('!'))
        {
            while(lexer.advanceUntilEither('"', '>') == 0)
                lexer.advanceUntil('"', true);
                    
            next.content = lexer.get[1..($-1)];
            if(next.content[$-1] == '/')
            {
                next.content = lexer.get()[0..($-1)];
                next.kind = NodeType.Kind.EMPTY_TAG;
            }
            else
                next.kind = NodeType.Kind.START_TAG;
        }
        
        // cdata or conditional
        else if(lexer.testAndAdvance('['))
        {
            lexer.advanceUntil('[', true);
            // cdata
            if(lexer.get()[3..$] == "CDATA[")
            {
                do
                    lexer.advanceUntil(']', true);
                while(!lexer.testAndAdvance(']') || !lexer.testAndAdvance('>'));
                
                next.content = lexer.get()[9..($-3)];
                next.kind = NodeType.Kind.CDATA;
            }
            // conditional
            else
            {
                int count = 1;
                do
                {
                    lexer.advanceUntilEither('[', '>');
                    if(lexer.get()[($-3)..$] == "<![")
                        count++;
                    else if(lexer.get()[($-3)..$] == "]]>")
                        count--;
                }
                while(count > 0);
                
                next.content = lexer.get()[3..($-3)];
                next.kind = NodeType.Kind.CONDITIONAL;
            }
        }
        // comment
        else if(lexer.testAndAdvance('-'))
        {
            lexer.testAndAdvance('-'); // second '-'
            do
                lexer.advanceUntil('-', true);
            while(!lexer.testAndAdvance('-') || !lexer.testAndAdvance('>'));
            next.content = lexer.get()[4..($-3)];
            next.kind = NodeType.Kind.COMMENT;
        }
        // declaration or doctype
        else
        {
            while(lexer.advanceUntilAny('"', '[', '>') == 0)
                lexer.advanceUntil('"', true);
                
            // doctype
            if(lexer.get()[2..9] == "DOCTYPE")
            {
                // inline dtd
                if(lexer.get()[$-1] == '[')
                {
                    while(lexer.advanceUntilEither('<', ']') == 0)
                        while(lexer.advanceUntilEither('"', '>') == 0)
                            lexer.advanceUntil('"', true);
                    lexer.advanceUntil('>', true);
                }
                next.content = lexer.get()[9..($-1)];
                next.kind = NodeType.Kind.DOCTYPE;
            }
            else
            {
                if(lexer.get()[$-1] == '[')
                    while(lexer.advanceUntilEither('"', '>') == 0)
                        lexer.advanceUntil('"', true);
                
                next.content = lexer.get()[2..($-1)];
                next.kind = NodeType.Kind.DECLARATION;
            }
        }
        
        ready = true;
    }
}

/*unittest
{
    import std.stdio;
    
    string xml = q{
    <?xml encoding="utf-8" ?>
    <aaa>
        <! ANYTHING HERE>
        <bbb>
            <!-- lol -->
            Lots of Text!
            On multiple lines!
        </bbb>
        <![CDATA[ Ciaone! ]]>
        <![conditional[ lalalala ]]>
    </aaa>
    };
    writeln(xml);
<<<<<<< HEAD
    
    {
        writeln("SliceLexer:");
        auto parser = Parser!(SliceLexer!string)();
        parser.setSource(xml);
        foreach(e; parser)
        {
            writeln(e);
        }
    }
    {
        writeln("RangeLexer:");
        auto parser = Parser!(RangeLexer!string)();
        parser.setSource(xml);
        foreach(e; parser)
        {
            writeln(e);
        }
=======
    auto parser = Parser!(RangeLexer!string)();
    parser.setSource(xml);
    foreach(e; parser)
    {
        writeln(e);
>>>>>>> df63fa6855a68852547ee25769cf812a9855ce30
    }
}*/

unittest
{
    import std.stdio;
    import std.file;
    import std.conv;
    import core.time;
    
<<<<<<< HEAD
    immutable int tests = 4;
    
    {
        writeln("SliceLexer:");
        auto parser = Parser!(SliceLexer!string)();
        for(int i = 0; i < tests; i++)
        {
            auto data = readText("../../tests/test_" ~ to!string(i) ~ ".xml");
            MonoTime before = MonoTime.currTime;
            parser.setSource(data);
            foreach(e; parser)
            {
            }
            MonoTime after = MonoTime.currTime;
            Duration elapsed = after - before;
            writeln("test ", i,": \t", elapsed, "\t(", data.length, " characters)");
        }
    }
    {
        writeln("RangeLexer:");
        auto parser = Parser!(RangeLexer!string)();
        for(int i = 0; i < tests; i++)
        {
            auto data = readText("../../tests/test_" ~ to!string(i) ~ ".xml");
            MonoTime before = MonoTime.currTime;
            parser.setSource(data);
            foreach(e; parser)
            {
            }
            MonoTime after = MonoTime.currTime;
            Duration elapsed = after - before;
            writeln("test ", i,": \t", elapsed, "\t(", data.length, " characters)");
        }
=======
    immutable int tests = 2;
    auto parser = Parser!(SliceLexer!string)();
    for(int i = 0; i < tests; i++)
    {
        auto data = readText("../../tests/test_" ~ to!string(i) ~ ".xml");
        MonoTime before = MonoTime.currTime;
        parser.setSource(data);
        foreach(e; parser)
        {
        }
        MonoTime after = MonoTime.currTime;
        Duration elapsed = after - before;
        writeln("test ", i,": \t", elapsed);
>>>>>>> df63fa6855a68852547ee25769cf812a9855ce30
    }
}