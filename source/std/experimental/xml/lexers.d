/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements various XML lexers.
+
+   The methods a lexer should implement are documented in
+   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`);
+   The different lexers here implemented are optimized for different kinds of input
+   and different tradeoffs between speed and memory usage.
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

module std.experimental.xml.lexers;

import std.experimental.xml.interfaces;
import std.experimental.xml.faststrings;

import std.range.primitives;
import std.traits: isArray;

import std.experimental.allocator;
import std.experimental.allocator.gc_allocator;

import std.typecons: Flag, Yes;

/++
+   A lexer that takes a sliceable input.
+
+   This lexer will always return slices of the original input; thus, it does not
+   allocate memory and calls to `start` don't invalidate the outputs of previous
+   calls to `get`.
+
+   This is the fastest of all lexers, as it only performs very quick searches and
+   slicing operations. It has the downside of requiring the entire input to be loaded
+   in memory at the same time; as such, it is optimal for small file but not suitable
+   for very big ones.
+
+   Parameters:
+       T = a sliceable type used as input for this lexer
+       Alloc = a dummy allocator parameter, never used; kept for uniformity with
+               the other lexers
+/
struct SliceLexer(T, Alloc = shared(GCAllocator))
{
    private T input;
    private size_t pos;
    private size_t begin;
    
    /++
    +   See detailed documentation in 
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    alias CharacterType = ElementEncodingType!T;
    /// ditto
    alias InputType = T;
    
    mixin UsesAllocator!Alloc;
    
    /// ditto
    void setSource(T input) @nogc
    {
        this.input = input;
        pos = 0;
    }
    
    static if(isForwardRange!T)
    {
        auto save() @nogc
        {
            SliceLexer result = this;
            result.input = input.save;
            return result;
        }
    }
    
    /// ditto
    auto empty() const @nogc
    {
        return pos >= input.length;
    }
    
    /// ditto
    void start() @nogc
    {
        begin = pos;
    }
    
    /// ditto
    CharacterType[] get() const @nogc
    {
        return input[begin..pos];
    }
    
    /// ditto
    void dropWhile(string s) @nogc
    {
        while (pos < input.length && fastIndexOf(s, input[pos]) != -1)
            pos++;
    }
    
    /// ditto
    bool testAndAdvance(char c) @nogc
    {
        if (input[pos] == c)
        {
            pos++;
            return true;
        }
        return false;
    }
    
    /// ditto
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
    
    /// ditto
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
+
+   This lexer copies the needed characters from the input range to an internal
+   buffer, returning slices of it. Whether the buffer is reused (and thus all
+   previously returned slices invalidated) depends on the instantiation parameters.
+
+   This is the most flexible lexer, as it imposes very few requirements on its input,
+   which only needs to be an InputRange. It is also the slowest lexer, as it copies
+   characters one by one, so it shall not be used unless it's the only option.
+   
+   Params:
+       T           = the InputRange to be used as input for this lexer
+       Alloc       = the allocator used to manage internal buffers
+       reuseBuffer = if set to `Yes` (the default) this parser will always reuse
+                     the same buffers, invalidating all previously returned slices
+/
struct RangeLexer(T, Alloc = shared(GCAllocator), Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer)
    if (isInputRange!T)
{
    import std.experimental.appender;
    
    /++
    +   See detailed documentation in 
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    alias CharacterType = ElementEncodingType!T;
    /// ditto
    alias InputType = T;
 
    mixin UsesAllocator!Alloc;

    private Appender!(CharacterType, Alloc) app;
    
    import std.string: representation;
    static if (is(typeof(representation!CharacterType(""))))
    {
        private typeof(representation!CharacterType("")) input;
        void setSource(T input)
        {
            this.input = input.representation;
            app = typeof(app)(allocator);
        }
    }
    else
    {
        private T input;
        void setSource(T input)
        {
            this.input = input;
            app = typeof(app)(allocator);
        }
    }
    
    static if (isForwardRange!T)
    {
        auto save()
        {
            RangeLexer result;
            result.input = input.save;
            result.app = typeof(app)(allocator);
            return result;
        }
    }
    
    /++
    +   See detailed documentation in 
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    bool empty() const
    {
        return input.empty;
    }
    
    /// ditto
    void start()
    {
        static if (reuseBuffer)
            app.clear;
        else
            app = typeof(app)(allocator);
    }
    
    /// ditto
    CharacterType[] get() const
    {
        return app.data;
    }
    
    /// ditto
    void dropWhile(string s)
    {
        while (!input.empty && fastIndexOf(s, input.front) != -1)
            input.popFront();
    }
    
    /// ditto
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
    
    /// ditto
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
    
    /// ditto
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

/++
+   A lexer that takes a ForwardRange.
+
+   This lexer copies the needed characters from the forward range to an internal
+   buffer, returning slices of it. Whether the buffer is reused (and thus all
+   previously returned slices invalidated) depends on the instantiation parameters.
+
+   This is slightly faster than `RangeLexer`, but shoudn't be used if a faster
+   lexer is available.
+   
+   Params:
+       T           = the InputRange to be used as input for this lexer
+       Alloc       = the allocator used to manage internal buffers
+       reuseBuffer = if set to `Yes` (the default) this parser will always reuse
+                     the same buffers, invalidating all previously returned slices
+/
struct ForwardLexer(T, Alloc = shared(GCAllocator), Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer)
    if (isForwardRange!T)
{
    import std.experimental.appender;
    
    /++
    +   See detailed documentation in 
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    alias CharacterType = ElementEncodingType!T;
    /// ditto
    alias InputType = T;
    
    mixin UsesAllocator!Alloc;
            
    private size_t count;    
    private Appender!(CharacterType, Alloc) app;
    
    import std.string: representation;
    static if (is(typeof(representation!CharacterType(""))))
    {
        private typeof(representation!CharacterType("")) input;
        private typeof(input) input_start;
        void setSource(T input)
        {
            app = typeof(app)(allocator);
            this.input = input.representation;
            this.input_start = this.input;
        }
    }
    else
    {
        private T input;
        private T input_start;
        void setSource(T input)
        {
            app = typeof(app)(allocator);
            this.input = input;
            this.input_start = input;
        }
    }
    
    auto save()
    {
        ForwardLexer result;
        result.input = input.save();
        result.input_start = input.save();
        result.app = typeof(app)(allocator);
        result.count = count;
        return result;
    }
    
    /++
    +   See detailed documentation in 
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    bool empty() const
    {
        return input.empty;
    }
    
    /// ditto
    void start()
    {
        static if (reuseBuffer)
            app.clear;
        else
            app = typeof(app)(allocator);
            
        input_start = input.save;
        count = 0;
    }
    
    /// ditto
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
    
    /// ditto
    void dropWhile(string s)
    {
        while (!input.empty && fastIndexOf(s, input.front) != -1)
            input.popFront();
        input_start = input.save;
    }
    
    /// ditto
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
    
    /// ditto
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
    
    /// ditto
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

/++
+   A lexer that takes an InputRange of slices from the input.
+
+   This lexer tries to merge the speed of direct slicing with the low memory requirements
+   of ranges. Its input is a range whose elements are chunks of the input data; this
+   lexer returns slices of the original chunks, unless the output is split between two
+   chunks. If that's the case, a new array is allocated and returned. The various chunks
+   may have different sizes.
+
+   The bigger the chunks are, the better is the performance and higher the memory usage,
+   so finding the correct tradeoff is crucial for maximum performance. This lexer is
+   suitable for very large files, which are read chunk by chunk from the file system.
+   
+   Params:
+       T           = the InputRange to be used as input for this lexer
+       Alloc       = the allocator used to manage internal buffers
+       reuseBuffer = if set to `Yes` (the default) this parser will always reuse
+                     the same buffers, invalidating all previously returned slices
+/
struct BufferedLexer(T, Alloc = shared(GCAllocator), Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer)
    if (isInputRange!T && isArray!(ElementType!T))
{
    import std.experimental.appender;
    
    alias BufferType = ElementType!T;
    
    /++
    +   See detailed documentation in 
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    alias CharacterType = ElementEncodingType!BufferType;
    /// ditto
    alias InputType = T;
    
    private InputType buffers;
    private size_t pos;
    private size_t begin;
        
    private Appender!(CharacterType, Alloc) app;
    private bool onEdge;
    
    mixin UsesAllocator!Alloc;
    
    import std.string: representation, assumeUTF;
    static if (is(typeof(representation!CharacterType(""))))
    {
        private typeof(representation!CharacterType("")) buffer;
        void popBuffer()
        {
            buffer = buffers.front.representation;
            buffers.popFront;
        }
    }
    else
    {
        private BufferType buffer;
        void popBuffer()
        {
            buffer = buffers.front;
            buffers.popFront;
        }
    }
    
    /++
    +   See detailed documentation in 
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    void setSource(T input)
    {
        app = typeof(app)(allocator);
        this.buffers = input;
        popBuffer;
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
            result.app = typeof(app)(allocator);
            return result;
        }
    }
    
    /++
    +   See detailed documentation in 
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    bool empty()
    {
        return buffers.empty && pos >= buffer.length;
    }
    
    /// ditto
    void start()
    {
        static if (reuseBuffer)
            app.clear;
        else
            app = typeof(app)(allocator);
            
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
            popBuffer;
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
        popBuffer;
        begin = 0;
        pos = 0;
    }
    
    /++
    +   See detailed documentation in 
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    CharacterType[] get() const
    {
        if (onEdge)
            return app.data;
        else
        {
            static if (is(typeof(representation!CharacterType(""))))
                return cast(CharacterType[])buffer[begin..pos];
            else
                return buffer[begin..pos];
        }
    }
    
    /// ditto
    void dropWhile(string s)
    {
        while (!empty && fastIndexOf(s, buffer[pos]) != -1)
            advance();
    }
    
    /// ditto
    bool testAndAdvance(char c)
    {
        if (buffer[pos] == c)
        {
            advance();
            return true;
        }
        return false;
    }
    
    /// ditto
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
    
    /// ditto
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

/++
+   Instantiates a `SliceLexer` specialized for the given input
+
+   Params:
+       Input = a type for which to instantiate a `SliceLexer`, or a value for
+               whose type to instantiate a `SliceLexer`
+
+   Returns:
+   An instance of `SliceLexer` specialized for the given `Input`. Note that even if
+   `Input` is a value, `setSource` is $(B not) called on the returned lexer
+/
auto chooseLexer(alias Input)()
{
    static if (is(SliceLexer!Input))
        return SliceLexer!Input();
    else static if (is(SliceLexer!(typeof(Input))))
        return SliceLexer!(typeof(Input))();
    else
        static assert(0);
}

/++
+   Instantiates a lexer specialized for the given input and allocator
+
+   Returns:
+   An instance of most suitable lexer type specialized for the given `Input` and `Alloc`.
+   Note that even if `Input` is a value, `setSource` is $(B not) called on the returned lexer
+/
template chooseLexer(alias Input, Alloc = shared(GCAllocator), Options...)
{
    import std.traits: hasMember;
    
    static if (is(SliceLexer!Input))
        static if (Options.length)
            alias Type = SliceLexer!(Input, Options);
        else
            alias Type = SliceLexer!Input;
    else static if (is(SliceLexer!(typeof(Input))))
        static if (Options.length)
            alias Type = SliceLexer!(typeof(Input), Options);
        else
            alias Type = SliceLexer!(typeof(Input));
    else static if (is(BufferedLexer!Input))
        static if (Options.length)
            alias Type = BufferedLexer!(Input, Options);
        else
            alias Type = BufferedLexer!Input;
    else static if (is(BufferedLexer!(typeof(Input))))
        static if (Options.length)
            alias Type = BufferedLexer!(typeof(Input), Options);
        else
            alias Type = BufferedLexer!(typeof(Input));
    else static if (is(RangeLexer!Input))
        static if (Options.length)
            alias Type = RangeLexer!(Input, Options);
        else
            alias Type = RangeLexer!Input;
    else static if (is(RangeLexer!(typeof(Input))))
    {
        static if (Options.length)
            alias Type = RangeLexer!(typeof(Input), Options);
        else
            alias Type = RangeLexer!(typeof(Input));
    }
    
    else static if (hasMember(Alloc, "instance"))
        auto chooseLexer(ref Alloc alloc = Alloc.instance)
        {
            return Type(alloc);
        }
    else
        auto chooseLexer(ref Alloc alloc)
        {
            return Type(alloc);
        }
}

version(unittest) 
{
    struct DumbBufferedReader
    {
        string content;
        size_t chunk_size;
        
        void popFront() @nogc
        {
            if (content.length > chunk_size)
                content = content[chunk_size..$];
            else
                content = [];
        }
        string front() const @nogc
        {
            if (content.length >= chunk_size)
                return content[0..chunk_size];
            else
                return content[0..$];
        }
        bool empty() const @nogc
        {
            return !content.length;
        }
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
 
@nogc unittest
{
    import std.experimental.allocator.mallocator;
    
    void testLexer(T)(T.InputType delegate(string) @nogc conv)
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
        
        auto alloc = Mallocator.instance;
    
        T lexer = T(&alloc);
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
    
    testLexer!(RangeLexer!(string, shared(Mallocator)))(x => x);
    testLexer!(ForwardLexer!(string, shared(Mallocator)))(x => x);
    testLexer!(BufferedLexer!(DumbBufferedReader, shared(Mallocator)))(x => DumbBufferedReader(x, 10));
}
