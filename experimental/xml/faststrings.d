
/++
+   This module implements fast search and compare
+   functions on slices. In the future, these may be
+   optimized by means of aggressive specialization,
+   inline assembly and SIMD instructions.
+/

module experimental.xml.faststrings;

pure bool fastEqual(T, S)(T[] t, S[] s)
{
    for(auto i = 0; i < t.length; i++)
        if(t[i] != s[i])
            return false;
    return true;
}

pure nothrow int fastIndexOf(T, S)(T[] t, S s)
{
    for(int i = 0; i < t.length; i++)
        if(t[i] == s)
            return i;
    return -1;
}