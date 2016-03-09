
module experimental.xml.lexer;

import interfaces;

import core.exception;
import std.array;
import std.range.primitives;
import std.string;
import std.traits;

import std.stdio;

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
    
    CharacterType[] readUntil(dchar c, bool included, bool returned)
    {
        auto start = pos;
        while(input[pos] != c)
            pos++;
        if(included)
            pos++;
        if(returned)
            return input[start..pos];
        else
            return input[start..(pos-1)];
    }
    CharacterType[] readUntil(dstring s, bool returned)
    {
        auto start = pos;
        while(!input[start..pos].endsWith(s))
            pos++;
        if(returned)
            return input[start..pos];
        else
            return input[start..(pos-s.length)];
    }
    
    CharacterType[] readBalanced(dstring begin, dstring end, bool returned)
    {
        auto start = pos;
        int count = 1;
        while(count > 0)
        {
            pos++;
            if(input[start..pos].endsWith(begin))
                count++;
            else if(input[start..pos].endsWith(end))
                count--;
        }
        if(returned)
            return input[start..pos];
        else
            return input[start..(pos-end.length)];
    }
    
    auto testAndEat(dchar c)
    {
        if(input[pos] == c)
        {
            pos++;
            return true;
        }
        return false;
    }
    
    void skip(dstring s)
    {
        while(pos < input.length)
            if(s.indexOf(input[pos]) != -1)
                pos++;
            else
                break;
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
    
    CharacterType[] readUntil(dchar c, bool included, bool returned)
    {
        auto app = appender!(CharacterType[])();
        while(input.front != c)
        {
            app.put(input.front);
            input.popFront();
        }
        if(returned)
            app.put(input.front);
        if(included)
            input.popFront();
        return app.data;
    }
    CharacterType[] readUntil(dstring s, bool returned)
    {
        auto app = appender!(CharacterType[])();
        while(!app.data.endsWith(s))
        {
            app.put(input.front);
            input.popFront();
        }
        if(returned)
            return app.data;
        else
            return app.data[0..($-s.length)];
    }
    
    CharacterType[] readBalanced(dstring begin, dstring end, bool returned)
    {
        auto app = appender!(CharacterType[])();
        int count = 1;
        while(count > 0)
        {
            app.put(input.front);
            input.popFront();
            if(app.data.endsWith(begin))
                count++;
            else if(app.data.endsWith(end))
                count--;
        }
        if(returned)
            return app.data;
        else
            return app.data[0..($-end.length)];
    }
    
    auto testAndEat(dchar c)
    {
        if(input.front == c)
        {
            input.popFront();
            return true;
        }
        return false;
    }
    
    void skip(dstring s)
    {
        while(!input.empty())
            if(s.indexOf(input.front) != -1)
                input.popFront();
            else
                break;
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
            lexer.skip(" \r\n\t");
            
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
            lexer.skip(" \r\n\t");
            
        if(lexer.empty)
            throw new EndOfStreamException();
        
        // text element
        if(!lexer.testAndEat('<'))
        {
            next.kind = NodeType.Kind.TEXT;
            next.content = lexer.readUntil('<', false, false);
            static if(!preserveSpaces)
                next.content = stripRight(next.content);
        }
        
        // tag end
        else if(lexer.testAndEat('/'))
        {
            next.content = lexer.readUntil('>', true, false);
            next.kind = NodeType.Kind.END_TAG;
        }
        // processing instruction
        else if(lexer.testAndEat('?'))
        {
            next.content = lexer.readUntil("?>", false);
            next.kind = NodeType.Kind.PROCESSING;
        }
        // tag start
        else if(!lexer.testAndEat('!'))
        {
            next.content = lexer.readUntil('>', true, false);
            if(next.content[$-1] == '/')
                next.kind = NodeType.Kind.EMPTY_TAG;
            else
                next.kind = NodeType.Kind.START_TAG;
        }
        
        // cdata or conditional
        else if(lexer.testAndEat('['))
        {
            next.content = lexer.readUntil('[', true, true);
            // cdata
            if(next.content == "CDATA[")
            {
                next.content = lexer.readUntil("]]>", false);
                next.kind = NodeType.Kind.CDATA;
            }
            // conditional
            else
            {
                next.content ~= lexer.readBalanced("<![", "]]>", false);
                next.kind = NodeType.Kind.CONDITIONAL;
            }
        }
        // comment
        else if(lexer.testAndEat('-'))
        {
            lexer.testAndEat('-'); // second '-'
            next.content = lexer.readUntil("-->", false);
            next.kind = NodeType.Kind.COMMENT;
        }
        // declaration
        else
        {
            next.content = lexer.readUntil('>', true, false);
            next.kind = NodeType.Kind.DECLARATION;
        }
        
        ready = true;
    }
}

unittest
{
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
    auto parser = Parser!(SliceLexer!string)();
    parser.setSource(xml);
    foreach(e; parser)
        writeln(e);
}