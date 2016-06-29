/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements various XML lexers.
+   The methods a lexer should implement are documented in experimental.xml.interfaces.
+/

module std.experimental.xml.lexers;

import std.experimental.xml.interfaces;
import std.experimental.xml.faststrings;

import std.array;
import std.range.primitives;
import std.traits: isArray;

/++
+   A lexer that takes a sliceable input.
+/
struct SliceLexer(T)
{
    alias CharacterType = ElementEncodingType!T;
    alias InputType = T;
    
    private T input;
    private size_t pos;
    private size_t begin;
    
    void setSource(T input) @nogc
    {
        this.input = input;
        pos = 0;
    }
    
    static if(isForwardRange!T)
    {
        auto save() const @nogc
        {
            SliceLexer result;
            result.input = input;
            result.pos = pos;
            return result;
        }
    }
    
    auto empty() const @nogc
    {
        return pos >= input.length;
    }
    
    void start() @nogc
    {
        begin = pos;
    }
    
    CharacterType[] get() const @nogc
    {
        return input[begin..pos];
    }
    
    void dropWhile(string s) @nogc
    {
        while (pos < input.length && fastIndexOf(s, input[pos]) != -1)
            pos++;
    }
    
    bool testAndAdvance(char c) @nogc
    {
        if (input[pos] == c)
        {
            pos++;
            return true;
        }
        return false;
    }
    
    void advanceUntil(char c, bool included) @nogc
    {
        auto adv = fastIndexOf(input[pos..$], c);
        if (adv != -1)
        {
            pos += adv;
        }
        else
        {
            pos = input.length;
        }
        
        if (included)
            pos++;
    }
    
    size_t advanceUntilAny(string s, bool included) @nogc
    {
        ptrdiff_t res;
        while ((res = fastIndexOf(s, input[pos])) == -1)
            pos++;
        if (included)
            pos++;
        return res;
    }
}

/++
+   A lexer that takes an InputRange.
+/
struct RangeLexer(T)
    if (isInputRange!T)
{
    alias CharacterType = ElementEncodingType!T;
    alias InputType = T;
    
    private T input;
    private Appender!(CharacterType[]) app;
    
    void setSource(T input)
    {
        this.input = input;
    }
    
    static if (isForwardRange!T)
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
        while (!input.empty && fastIndexOf(s, input.front) != -1)
            input.popFront();
    }
    
    bool testAndAdvance(char c)
    {
        if (input.front == c)
        {
            app.put(input.front);
            input.popFront();
            return true;
        }
        return false;
    }
    
    void advanceUntil(char c, bool included)
    {
        while (input.front != c)
        {
            app.put(input.front);
            input.popFront();
        }
        if (included)
        {
            app.put(input.front);
            input.popFront();
        }
    }
    
    size_t advanceUntilAny(string s, bool included)
    {
        size_t res;
        while ((res = fastIndexOf(s, input.front)) == -1)
        {
            app.put(input.front);
            input.popFront;
        }
        if (included)
        {
            app.put(input.front);
            input.popFront;
        }
        return res;
    }
}

struct ForwardLexer(T)
    if (isForwardRange!T)
{
    alias CharacterType = ElementEncodingType!T;
    alias InputType = T;
    
    private T input;
    private T input_start;
    private size_t count;
    private Appender!(CharacterType[]) app;
    
    void setSource(T input)
    {
        this.input = input;
        this.input_start = input;
    }
    
    auto save() const
    {
        ForwardLexer result;
        result.input = input.save();
        result.input_start = input.save();
        result.count = count;
        return result;
    }
    
    bool empty() const
    {
        return input.empty;
    }
    
    void start()
    {
        app = appender!(CharacterType[])();
        input_start = input.save;
        count = 0;
    }
    
    CharacterType[] get()
    {
        import std.range: take;
        auto diff = count - app.data.length;
        if (diff)
        {
            app.reserve(diff);
            app.put(input_start.take(diff));
        }
        return app.data;
    }
    
    void dropWhile(string s)
    {
        while (!input.empty && fastIndexOf(s, input.front) != -1)
            input.popFront();
        input_start = input.save;
    }
    
    bool testAndAdvance(char c)
    {
        if (input.front == c)
        {
            count++;
            input.popFront();
            return true;
        }
        return false;
    }
    
    void advanceUntil(char c, bool included)
    {
        while (input.front != c)
        {
            count++;
            input.popFront();
        }
        if (included)
        {
            count++;
            input.popFront();
        }
    }
    
    size_t advanceUntilAny(string s, bool included)
    {
        size_t res;
        while ((res = fastIndexOf(s, input.front)) == -1)
        {
            count++;
            input.popFront;
        }
        if (included)
        {
            count++;
            input.popFront;
        }
        return res;
    }
}

struct BufferedLexer(T)
    if (isInputRange!T && isArray!(ElementType!T))
{
    alias BufferType = ElementType!T;
    alias CharacterType = ElementEncodingType!BufferType;
    alias InputType = T;
    
    InputType buffers;
    BufferType buffer;
    size_t pos;
    size_t begin;
    Appender!(CharacterType[]) app;
    bool onEdge;
    
    void setSource(T input)
    {
        this.buffers = input;
        buffer = buffers.front;
        buffers.popFront;
    }
    
    static if (isForwardRange!T)
    {
        auto save() const
        {
            BufferedLexer result;
            result.buffers = buffers.save();
            result.buffer = buffer;
            result.pos = pos;
            result.begin = begin;
            return result;
        }
    }
    
    bool empty()
    {
        return buffers.empty && pos >= buffer.length;
    }
    
    void start()
    {
        app = appender!(CharacterType[])();
        begin = pos;
        onEdge = false;
    }
    
    private void advance()
    {
        if (pos + 1 >= buffer.length)
        {
            if (onEdge)
                app.put(buffer[pos]);
            else
            {
                app.put(buffer[begin..$]);
                onEdge = true;
            }
            buffer = buffers.front;
            buffers.popFront;
            begin = 0;
            pos = 0;
        }
        else if (onEdge)
            app.put(buffer[pos++]);
        else
            pos++;
    }
    private void advance(ptrdiff_t n)
    {
        foreach(i; 0..n)
            advance();
    }
    private void advanceNextBuffer()
    {
        if (onEdge)
            app.put(buffer[pos..$]);
        else
        {
            app.put(buffer[begin..$]);
            onEdge = true;
        }
        buffer = buffers.front;
        buffers.popFront;
        begin = 0;
        pos = 0;
    }
    
    CharacterType[] get() const
    {
        if (onEdge)
            return app.data;
        else
            return buffer[begin..pos];
    }
    
    void dropWhile(string s)
    {
        while (!empty && fastIndexOf(s, buffer[pos]) != -1)
            advance();
    }
    
    bool testAndAdvance(char c)
    {
        if (buffer[pos] == c)
        {
            advance();
            return true;
        }
        return false;
    }
    
    void advanceUntil(char c, bool included)
    {
        ptrdiff_t adv;
        while ((adv = fastIndexOf(buffer[pos..$], c)) == -1)
        {
            advanceNextBuffer();
        }
        advance(adv);
        
        if (included)
            advance();
    }
    
    size_t advanceUntilAny(string s, bool included)
    {
        ptrdiff_t res;
        while ((res = fastIndexOf(s, buffer[pos])) == -1)
        {
            advance();
        }
        if (included)
            advance();
        return res;
    }
}

auto withInput(T)(auto ref T input)
{
    struct Chain
    {
        alias Type = T;
        auto finalize()
        {
            return input;
        }
    }
    return Chain();
}

auto lex(T)(auto ref T input)
{
    static if (__traits(compiles, SliceLexer!(T.Type)))
    {
        struct Chain
        {
            alias Type = SliceLexer!(T.Type);
            auto finalize()
            {
                return Type(input.finalize, 0, 0);
            }
        }
    }
    else if (__traits(compiles, RangeLexer!(T.Type)))
    {
        struct Chain
        {
            alias Type = RangeLexer!(T.Type);
            auto finalize()
            {
                return Type(input.finalize, Appender!(Type.CharacterType[])());
            }
        }
    }
    else
    {
        static assert(0);
    }
    return chain;
}
 
struct DumbBufferedReader
{
    string content;
    size_t chunk_size;
    
    void popFront()
    {
        if (content.length > chunk_size)
            content = content[chunk_size..$];
        else
            content = [];
    }
    string front() const
    {
        if (content.length >= chunk_size)
            return content[0..chunk_size];
        else
            return content[0..$];
    }
    bool empty() const
    {
        return !content.length;
    }
}
 
unittest
{

    void testLexer(T)(T.InputType delegate(string) conv)
    {
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
        
        T lexer;
        lexer.setSource(conv(xml));
        
        lexer.dropWhile(" \r\n\t");
        lexer.start();
        lexer.advanceUntilAny(":>", true);
        assert(lexer.get() == "<?xml encoding = \"utf-8\" ?>");
        
        lexer.dropWhile(" \r\n\t");
        lexer.start();
        lexer.advanceUntilAny("=:", false);
        assert(lexer.get() == "<aaa xmlns");
        
        lexer.start();
        lexer.advanceUntil('>', true);
        assert(lexer.get() == ":myns=\"something\">");
        
        lexer.dropWhile(" \r\n\t");
        lexer.start();
        lexer.advanceUntil('\'', true);
        assert(lexer.testAndAdvance('>'));
        lexer.advanceUntil('>', false);
        assert(lexer.testAndAdvance('>'));
        assert(lexer.get() == "<myns:bbb myns:att='>'>");
        
        assert(!lexer.empty);
    }
    
    testLexer!(SliceLexer!string)(x => x);
    testLexer!(RangeLexer!string)(x => x);
    testLexer!(ForwardLexer!string)(x => x);
    testLexer!(BufferedLexer!DumbBufferedReader)(x => DumbBufferedReader(x, 10));
}
