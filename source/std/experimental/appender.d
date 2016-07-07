
module std.experimental.appender;

struct Appender(T, alias Alloc)
{
    import std.experimental.allocator.gc_allocator;
    static if(is(Alloc : GCAllocator) || is(typeof(Alloc) : GCAllocator))
    {
        static import std.array;
        std.array.Appender!(T[]) _p_app;
        alias _p_app this;
    }
    else
    {
        import std.array;
        import std.range.primitives;
        import std.traits;
        import std.string: representation;

        private Unqual!T[] arr;
        private size_t used;
        
        public void put(U)(U item) @nogc
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
        
        private void enlarge(size_t sz) @nogc
        {
            import std.algorithm: max;
            import std.experimental.allocator: makeArray, dispose;
            import core.stdc.string: memcpy;
            
            if(!arr)
                arr = Alloc.makeArray!(Unqual!T)(sz);
            else
            {
                size_t newSz;
                if (arr.length < 256)
                    newSz = max(arr.length * 2, arr.length + sz);
                else
                    newSz = max((arr.length * 3)/2, arr.length + sz);
                
                auto newArr = Alloc.makeArray!(Unqual!T)(newSz);
                memcpy(newArr.ptr, arr.ptr, used * T.sizeof);
                Alloc.dispose(arr);
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
}

unittest
{
    import std.experimental.allocator.mallocator;
    
    auto app = Appender!(int, Mallocator.instance)();
    assert(app.data is null);
    
    app.put(1);
    assert(app.data == [1]);
    
    app.put([2, 3, 4]);
    assert(app.data == [1, 2, 3, 4]);
}