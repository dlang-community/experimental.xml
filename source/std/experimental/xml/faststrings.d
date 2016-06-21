/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements fast search and compare
+   functions on slices. In the future, these may be
+   optimized by means of aggressive specialization,
+   inline assembly and SIMD instructions.
+/

module std.experimental.xml.faststrings;

/++ Compares for equality; input slices must have equal length. +/
bool fastEqual(T, S)(T[] t, S[] s) pure @nogc nothrow
in
{
    assert(t.length == s.length);
}
body
{
    import core.stdc.string: memcmp;
    return memcmp(t.ptr, s.ptr, t.length) == 0;
}
unittest
{
    assert( fastEqual("ciao", "ciao"));
    assert(!fastEqual("ciao", "ciAo"));
    assert( fastEqual([1, 2], [1, 2]));
    assert(!fastEqual([1, 2], [2, 1]));
}

/++ Returns the index of the first occurrence of a value in a slice. +/
ptrdiff_t fastIndexOf(T, S)(T[] t, S s) pure @nogc nothrow
{
    foreach (i; 0 .. t.length)
        if (t[i] == s)
            return i;
    return -1;
}
unittest
{
    assert(fastIndexOf("FoO", 'O') == 2);
    assert(fastIndexOf([1, 2], 3.14) == -1);
}

/++ 
+ Returns the index of the first occurrence of any of the values in the second
+ slice inside the first one.
+/
ptrdiff_t fastIndexOfAny(T, S)(T[] t, S[] s) pure @nogc nothrow
{
    foreach (i; 0 .. t.length)
        if (fastIndexOf(s, t[i]) != -1)
            return i;
    return -1;
}
unittest
{
    assert(fastIndexOfAny([1, 2, 3, 4], [5, 4, 3]) == 2);
    assert(fastIndexOfAny("Foo", "baz") == -1);
}

/++
+ Returns the index of the first occurrence of a value of the first slice that
+ does not appear in the second.
+/
ptrdiff_t fastIndexOfNeither(T, S)(T[] t, S[] s) pure @nogc nothrow
{
    foreach (i; 0 .. t.length)
        if (fastIndexOf(s, t[i]) == -1)
            return i;
    return -1;
}
unittest
{
    assert(fastIndexOfNeither("lulublubla", "luck") == 4);
    assert(fastIndexOfNeither([1, 3, 2], [2, 3, 1]) == -1);
}
