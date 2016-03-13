
module experimental.xml.lexer;

import experimental.xml.interfaces;

import core.exception;
import std.array;
import std.range.primitives;
import std.string;
import std.traits;

pure bool fastEqual(T, S)(T[] t, S[] s)
{
    for(auto i = 0; i < t.length; i++)
        if(t[i] != s[i])
            return false;
    return true;
}

pure nothrow int fastIndexOf(T, S)(T[] t, S s)
{
    for(int i = 0; i < t.length; i++)
        if(t[i] == s)
            return i;
    return -1;
}

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
        while(pos < input.length && fastIndexOf(s, input[pos]) != -1)
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
        auto adv = fastIndexOf(input[pos..$], c);
        if(adv != -1)
            pos += adv;
        else
            pos = input.length;
        if(included)
            pos++;
    }
    
    int advanceUntilAny(string s, bool included)
    {
        int res;
        while((res = fastIndexOf(s, input[pos])) == -1)
            pos++;
        if(included)
            pos++;
        return res;
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
    {
        while(!input.empty && fastIndexOf(s, input.front) != -1)
            input.popFront();
    }
    
    bool testAndAdvance(char c)
    {
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
    
    int advanceUntilAny(string s, bool included)
    {
        int res;
        while((res = fastIndexOf(s, input.front)) == -1)
        {
            app.put(input.front);
            input.popFront;
        }
        if(included)
        {
            app.put(input.front);
            input.popFront;
        }
        return res;
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
        static if(!preserveSpaces)
            lexer.dropWhile(" \r\n\t");
        
        if(lexer.empty)
            throw new EndOfStreamException();
        
        lexer.start();
        
        // text element
        if(!lexer.testAndAdvance('<'))
        {
            lexer.advanceUntil('<', false);
            next.kind = NodeType.Kind.TEXT;
            next.content = lexer.get();
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
            int c;
            do
                while((c = lexer.advanceUntilAny("\"'?", true)) < 2)
                    if(c == 0)
                        lexer.advanceUntil('"', true);
                    else
                        lexer.advanceUntil('\'', true);
            while(!lexer.testAndAdvance('>'));
            next.content = lexer.get()[2..($-2)];
            next.kind = NodeType.Kind.PROCESSING;
        }
        // tag start
        else if(!lexer.testAndAdvance('!'))
        {
            int c;
            while((c = lexer.advanceUntilAny("\"'/>", true)) < 2)
                if(c == 0)
                    lexer.advanceUntil('"', true);
                else
                    lexer.advanceUntil('\'', true);
                    
            if(c == 2)
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
        else if(lexer.testAndAdvance('['))
        {
            lexer.advanceUntil('[', true);
            // cdata
            if(fastEqual(lexer.get()[3..$], "CDATA["))
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
                    lexer.advanceUntilAny("[>", true);
                    if(lexer.get()[($-3)..$] == "]]>")
                        count--;
                    else if(lexer.get()[($-3)..$] == "<![")
                        count++;
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
            int c;
            while((c = lexer.advanceUntilAny("\"'[>", true)) < 2)
                if(c == 0)
                    lexer.advanceUntil('"', true);
                else
                    lexer.advanceUntil('\'', true);
                
            // doctype
            if(fastEqual(lexer.get()[2..9], "DOCTYPE"))
            {
                // inline dtd
                if(c == 2)
                {
                    while(lexer.advanceUntilAny("<]", true) == 0)
                        // comment
                        if(lexer.testAndAdvance('-'))
                            do
                                lexer.advanceUntil('-', true);
                            while(!lexer.testAndAdvance('-') || !lexer.testAndAdvance('>'));
                        // processing instruction
                        else if(lexer.testAndAdvance('?'))
                        {
                            int cc;
                            do
                                while((cc = lexer.advanceUntilAny("\"'?", true)) < 2)
                                    if(cc == 0)
                                        lexer.advanceUntil('"', true);
                                    else
                                        lexer.advanceUntil('\'', true);
                            while(!lexer.testAndAdvance('>'));
                        }
                        // entity, notation or attlist
                        else
                        {
                            int cc;
                            while((cc = lexer.advanceUntilAny("\"'>", true)) < 2)
                                if(cc == 0)
                                    lexer.advanceUntil('"', true);
                                else
                                    lexer.advanceUntil('\'', true);
                        }
                    lexer.advanceUntil('>', true);
                }
                next.content = lexer.get()[9..($-1)];
                next.kind = NodeType.Kind.DOCTYPE;
            }
            else
            {
                if(c == 2)
                {
                    int cc;
                    while((cc = lexer.advanceUntilAny("\"'>", true)) < 2)
                        if(cc == 0)
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
    import std.stdio;
    
    string xml = q{
    <?xml encoding="utf-8" ?>
    <aaa>
        <! ANYTHING HERE>
        <bbb att='>'>
            <!-- lol -->
            Lots of Text!
            On multiple lines!
        </bbb>
        <![CDATA[ Ciaone! ]]>
        <![conditional[ lalalala ]]>
    </aaa>
    };
    writeln(xml);
    
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
    }
}

unittest
{
    import std.stdio;
    import std.file;
    import std.conv;
    import core.time;
    
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
    }
}