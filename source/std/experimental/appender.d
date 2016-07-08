
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
            /* may throwable operation:
             * - std.utf.encode
             */
            // must do some transcoding around here
            /*import std.utf : encode;
            Unqual!T[T.sizeof == 1 ? 4 : 2] encoded;
            auto len = encode(encoded, item);
            put(encoded[0 .. len]);*/
            assert(0);
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
        static if (__traits(compiles, range.length))
        {
            alias U = ElementEncodingType!Range;
            auto len = range.length;
            static if (isSomeChar!T && isSomeChar!U)
            {
                static if (T.sizeof < U.sizeof)
                {
                    /*import std.utf : encode;
                    Unqual!T[(T.sizeof == 1 ? 4 : 2)*len] encoded;
                    len = encode(encoded, item);
                    put(encoded[0 .. len]);*/
                    assert(0);
                }
                else static if (isArray!Range)
                {
                    put(range.representation);
                }
            }
            else
            {
                if (arr.length - used < len)
                    enlarge(len - (arr.length - used));
                for(; !range.empty; range.popFront)
                    arr[used++] = cast(T)range.front;
            }
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
        import std.experimental.allocator: makeArray, dispose;
        import core.stdc.string: memcpy;
        
        if(!arr)
            arr = allocator.makeArray!(Unqual!T)(sz);
        else
        {
            size_t newSz;
            if (arr.length < 256)
                newSz = max(arr.length * 2, arr.length + sz);
            else
                newSz = max((arr.length * 3)/2, arr.length + sz);
            
            auto newArr = allocator.makeArray!(Unqual!T)(newSz);
            memcpy(newArr.ptr, arr.ptr, used * T.sizeof);
            allocator.dispose(arr);
            arr = newArr;
        }
    }
    
    public void reserve(size_t size)
    {
        enlarge(size);
    }
    
    public auto data() const
    {
        return cast(T[])arr[0..used];
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