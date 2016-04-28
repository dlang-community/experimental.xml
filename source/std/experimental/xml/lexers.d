
/++
+   This module implements various XML lexers.
+   The methods a lexer should implement are documented in experimental.xml.interfaces.
+/

module std.experimental.xml.lexers;

import std.experimental.xml.interfaces;
import std.experimental.xml.faststrings;

import std.array;
import std.range.primitives;

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
        while (pos < input.length && fastIndexOf(s, input[pos]) != -1)
            pos++;
    }
    
    bool testAndAdvance(char c)
    {
        if (input[pos] == c)
        {
            pos++;
            return true;
        }
        return false;
    }
    
    void advanceUntil(char c, bool included)
    {
        auto adv = fastIndexOf(input[pos..$], c);
        if (adv != -1)
            pos += adv;
        else
            pos = input.length;
        if (included)
            pos++;
    }
    
    int advanceUntilAny(string s, bool included)
    {
        int res;
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
    
    int advanceUntilAny(string s, bool included)
    {
        int res;
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