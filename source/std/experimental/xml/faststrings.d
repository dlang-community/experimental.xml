
/++
+   This module implements fast search and compare
+   functions on slices. In the future, these may be
+   optimized by means of aggressive specialization,
+   inline assembly and SIMD instructions.
+/

module std.experimental.xml.faststrings;

pure bool fastEqual(T, S)(T[] t, S[] s)
{
    for (auto i = 0; i < t.length; i++)
        if (t[i] != s[i])
            return false;
    return true;
}

pure int fastIndexOf(T, S)(T[] t, S s)
{
    for (int i = 0; i < t.length; i++)
        if (t[i] == s)
            return i;
    return -1;
}

pure int fastIndexOfAny(T, S)(T[] t, S[] s)
{
    for (int i = 0; i < t.length; i++)
        if (fastIndexOf(s, t[i]) != -1)
            return i;
    return -1;
}

pure int fastIndexOfNeither(T, S)(T[] t, S[] s)
{
    for (int i = 0; i < t.length; i++)
        if (fastIndexOf(s, t[i]) == -1)
            return i;
    return -1;
}
