/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module std.experimental.appender;

struct Appender(T, Alloc)
{
    import std.experimental.allocator;   
    import std.array;
    import std.range.primitives;
    import std.traits;
    import std.string: representation;
    
    Alloc* allocator;
    private Unqual!T[] arr;
    private size_t used;
    
    public this(ref Alloc alloc)
    {
        allocator = &alloc;
    }
    public this(Alloc* alloc)
    {
        allocator = alloc;
    }
    
    public void put(U)(U item)
        if(!isInputRange!U)
    {
        static if (isSomeChar!T && isSomeChar!U && T.sizeof < U.sizeof)
        {
            import std.utf : encode, UseReplacementDchar;
            Unqual!T[T.sizeof == 1 ? 4 : 2] encoded;
            auto len = encode!(UseReplacementDchar.yes)(encoded, item);
            put(encoded[0 .. len]);
        }
        else
        {
            if(!arr || arr.length == used)
                enlarge(1);
            arr[used++] = cast(T)item;
        }
    }
    
    public void put(Range)(Range range)
        if (isInputRange!Range)
    {
        static if (isArray!Range)
        {
            alias U = ElementEncodingType!Range;
            auto len = range.length;
            static if (is(T == U))
            {
                import core.stdc.string: memcpy;
                if (arr.length - used < len)
                    enlarge(len - (arr.length - used));
                memcpy(arr.ptr + used, range.ptr, len*U.sizeof);
                used += len;
            }
            else static if (isSomeChar!T && isSomeChar!U)
            {
                import std.utf : encode, UseReplacementDchar;
                Unqual!T[(T.sizeof == 1 ? 4 : 2)*len] encoded;
                len = encode!(UseReplacementDchar.yes)(encoded, item);
                put(encoded[0 .. len]);
            }
            else
            {
                if (arr.length - used < len)
                    enlarge(len - (arr.length - used));
                for(; !range.empty; range.popFront)
                    arr[used++] = cast(T)range.front;
            }
        }
        else static if (__traits(compiles, range.length))
        {
            auto len = range.length;   
            if (arr.length - used < len)
                enlarge(len - (arr.length - used));
            for(; !range.empty; range.popFront)
                arr[used++] = cast(T)range.front;
        }
        else
        {
            for(; !range.empty; range.popFront)
                put(range.front);
        }
    }
    
    private void enlarge(size_t sz)
    {
        import std.algorithm: max;
        
        size_t delta;
        if (arr.length < 256)
            delta = max(arr.length, sz);
        else
            delta = max(arr.length/2, sz);
        assert(allocator.expandArray(arr, delta), "Could not grow appender array");
    }
    
    public void reserve(size_t size)
    {
        enlarge(size);
    }
    
    public auto data() const
    {
        return cast(T[])arr[0..used];
    }
    
    public void reset()
    {
        used = 0;
    }
    
    public void free()
    {
        if (arr)
        {
            import std.experimental.allocator: dispose;
            allocator.dispose(arr);
            used = 0;
            arr = [];
        }
    }
}

@nogc unittest
{
    import std.experimental.allocator.mallocator;
    
    static immutable arr1 = [1];
    static immutable arr234 = [2, 3, 4];
    static immutable arr1234 = [1, 2, 3, 4];
    
    auto app = Appender!(int, shared(Mallocator))(Mallocator.instance);
    assert(app.data is null);
    
    app.put(1);
    assert(app.data == arr1);
    
    app.put(arr234);
    assert(app.data == arr1234);
}