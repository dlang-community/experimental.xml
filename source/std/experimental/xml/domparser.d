/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module std.experimental.xml.domparser;

import std.experimental.xml.interfaces;
import std.experimental.xml.cursor;

import std.experimental.xml.dom;
/++
+   Built on top of Cursor, the DOM builder adds to it the ability to 
+   build a DOM node representing the node at the current position and, if
+   needed, its children. This allows for advanced usages like skipping entire
+   subtrees of the document, or connecting some nodes directly to their grand-parents,
+   skipping one layer of the hierarchy.
+/
struct DOMBuilder(T, Alloc)
    if (isCursor!T)
{   
    /++
    +   The underlying Cursor methods are exposed, so that one can, for example,
    +   use the cursor API to skip some nodes.
    +/
    T cursor;
    alias cursor this;
    
    alias StringType = T.StringType;
    
    private Node!StringType currentNode;
    
    void setSource(T.InputType input)
    {
        cursor.setSource(input);
    }
    
    /++
    +   Adds the current node to the DOM tree; if the DOM tree does not exist yet,
    +   the current node becomes its root; if the current node is not a descendant of 
    +   the root of the DOM tree, the DOM tree is discarded and the current node becomes
    +   the root of a new DOM tree.
    +/
    void build();
    
    /++
    +   Builds the current node and all of its descendants, as specified in build().
    +   Also advances the cursor to the end of the current element.
    +/
    void buildRecursive();
    
    /++ Returns the DOM tree built by this builder. +/
    Document!StringType getDOMTree() const;
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.experimental.xml.cursor;
    import std.experimental.allocator.gc_allocator;
    
    alias CursorType = Cursor!(Parser!(SliceLexer!string));
    
    auto builder = DOMBuilder!(CursorType, GCAllocator)();
}
