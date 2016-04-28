
/++
+   This module implements fast search and compare
+   functions on slices. In the future, these may be
+   optimized by means of aggressive specialization,
+   inline assembly and SIMD instructions.
+/

module std.experimental.xml.faststrings;

/++ Compares for equality; input slices must have equal length. +/
pure bool fastEqual(T, S)(T[] t, S[] s)
in
{
    assert(t.length == s.length);
}
body
{
    for (auto i = 0; i < t.length; i++)
        if (t[i] != s[i])
            return false;
    return true;
}
unittest
{
    assert( fastEqual("ciao", "ciao"));
    assert(!fastEqual("ciao", "ciAo"));
    assert( fastEqual([1, 2], [1, 2]));
    assert(!fastEqual([1, 2], [2, 1]));
}

/++ Returns the index of the first occurrence of a value in a slice. +/
pure int fastIndexOf(T, S)(T[] t, S s)
{
    for (int i = 0; i < t.length; i++)
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
pure int fastIndexOfAny(T, S)(T[] t, S[] s)
{
    for (int i = 0; i < t.length; i++)
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
pure int fastIndexOfNeither(T, S)(T[] t, S[] s)
{
    for (int i = 0; i < t.length; i++)
        if (fastIndexOf(s, t[i]) == -1)
            return i;
    return -1;
}
unittest
{
    assert(fastIndexOfNeither("lulublubla", "luck") == 4);
    assert(fastIndexOfNeither([1, 3, 2], [2, 3, 1]) == -1);
}
