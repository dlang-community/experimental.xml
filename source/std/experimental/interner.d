/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module std.experimental.interner;

import std.traits: isArray, hasElaborateCopyConstructor;
import std.typecons: Rebindable, rebindable;

alias Hasher(T) = size_t function(const T) @safe pure nothrow;
alias Comparer(T) = bool function(const T, const T) @safe pure nothrow;

enum OnIntern
{
    NoAction,
    Duplicate
}

import std.experimental.allocator.gc_allocator;
struct Interner(T, OnIntern onIntern = OnIntern.NoAction, Alloc = shared(GCAllocator))
{
    private Rebindable!(immutable(T))[const T] interner;
    
    private Alloc* allocator;
    this(Alloc* alloc)
    {
        allocator = alloc;
    }
    this(ref Alloc alloc)
    {
        allocator = &alloc;
    }
    
    bool contains(const T val) const @safe pure nothrow @nogc
    {
        return cast(bool)(val in interner);
    }
    static if (onIntern == OnIntern.Duplicate)
    {
        immutable(T) intern(const T val)
        {
            if (val !in interner)
            {
                import std.experimental.allocator;
                import core.stdc.string: memcpy;
                static if (isArray!T && !hasElaborateCopyConstructor!T)
                {
                    auto len = val.length * typeof(val[0]).sizeof;
                    auto copy = allocator.allocate(len);
                    memcpy(copy.ptr, val.ptr, len);
                    interner[cast(immutable T)copy] = rebindable(cast(immutable T)copy);
                }
                else static assert(0, "Types other than arrays are not currently supported for duplication");
            }
            return interner[val];
        }
    }
    else
    {
        immutable(T) intern(immutable T val) @safe pure
        {
            if (val !in interner)
                interner[val] = val;
            return interner[val];
        }
    }
    bool remove(const T val) @safe pure nothrow
    {
        return interner.remove(val);
    }
}

private struct InternalKeyType(T, alias comparer, alias hasher)
{
    immutable T value;
    size_t toHash() const @safe pure nothrow
    {
        return hasher(value);
    }
    bool opEquals(ref const InternalKeyType other) const @safe pure nothrow
    {
        return comparer(value, other.value);
    }
};
    
struct Interner(T, alias hasher, alias comparer, OnIntern onIntern = OnIntern.NoAction, Alloc = shared(GCAllocator))
    if (is(typeof(hasher) : Hasher!T) && is(typeof(comparer) : Comparer!T))
{
    alias KeyType = InternalKeyType!(T, comparer, hasher);
    
    private Rebindable!(immutable(T))[const KeyType] interner;
    
    private Alloc* allocator;
    this(Alloc* alloc)
    {
        allocator = alloc;
    }
    this(ref Alloc alloc)
    {
        allocator = &alloc;
    }
    
    bool contains(const T val) const @safe pure nothrow @nogc
    {
        return cast(bool)(KeyType(val) in interner);
    }
    static if (onIntern == OnIntern.Duplicate)
    {
        immutable(T) intern(const T val)
        {
            auto key = KeyType(val);
            if (key !in interner)
            {
                import std.experimental.allocator;
                import core.stdc.string: memcpy;
                static if (isArray!T && !hasElaborateCopyConstructor!T)
                {
                    auto len = val.length * typeof(val[0]).sizeof;
                    auto copy = allocator.allocate(len);
                    memcpy(copy.ptr, val.ptr, len);
                    key = KeyType(cast(immutable T)copy);
                    interner[key] = rebindable(cast(immutable T)copy);
                }
                else static assert(0, "Types other than arrays are not currently supported for duplication");
            }
            return interner[key];
        }
    }
    else
    {
        immutable(T) intern(immutable T val) @safe pure
        {
            auto key = KeyType(val);
            if (key !in interner)
                interner[key] = rebindable(val);
            return interner[key];
        }
    }
    bool remove(const T val) @safe pure
    {
        return interner.remove(KeyType(val));
    }
}

unittest
{
    auto a = "Hello, world";
    auto b = "String interning";
    {
        Interner!string interner;
        assert(interner.intern(a) is a);
        assert(interner.intern(a.idup) is a);
        assert(interner.intern(b) is b);
        assert(interner.intern(b.idup) is b);
    }
    {
        import std.algorithm: map;
        import std.uni: toLower;
        
        enum hasher = function size_t(const string s) @safe pure nothrow { return 1; };
        enum comparer = function bool(const string s1, const string s2) @safe pure nothrow
        {
            try
            {
                return s1.toLower == s2.toLower;
            }
            catch (Exception)
            {
                return false;
            }
        };
        
        Interner!(string, hasher, comparer) interner;
        assert(interner.intern(a) is a);
        assert(interner.intern(a.toLower) is a);
        assert(interner.intern(b) is b);
        assert(interner.intern(b.toLower) is b);
    }
    {
        Interner!(string, OnIntern.Duplicate) interner;
        auto interned_a = interner.intern(a);
        auto interned_b = interner.intern(b);
        assert(interned_a !is a);
        assert(interned_b !is b);
        assert(interner.intern(a.dup) is interned_a);
        assert(interner.intern(b.dup) is interned_b);
    }
}