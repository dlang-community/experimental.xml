/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module std.experimental.xml.domparser;

import std.experimental.xml.interfaces;
import std.experimental.xml.cursor;

import dom = std.experimental.xml.dom;
/++
+   Built on top of Cursor, the DOM builder adds to it the ability to 
+   build the DOM tree of the document; as the cursor advances, nodes can be
+   selectively added to the tree, allowing to built a small representation
+   containing only the needed parts of the document.
+/
struct DOMBuilder(T, DOMImplementation = dom.DOMImplementation!(T.StringType))
    if (isCursor!T && is(DOMImplementation : dom.DOMImplementation!(T.StringType)))
{   
    import std.traits: ReturnType;

    /++
    +   The underlying Cursor methods are exposed, so that one can, for example,
    +   use the cursor API to skip some nodes.
    +/
    T cursor;
    alias cursor this;
    
    alias StringType = T.StringType;
    
    alias DocumentType = ReturnType!(DOMImplementation.createDocument);
    alias NodeType = typeof(DocumentType.firstChild);
    
    private NodeType currentNode;
    private DocumentType document;
    private DOMImplementation domImpl;
    private bool already_built;
    
    /++ Generic constructor; forwards its arguments to the lexer constructor +/
    this(Args...)(DOMImplementation impl, auto ref Args args)
    {
        cursor = typeof(cursor)(args);
        domImpl = impl;
    }
    
    void setSource(T.InputType input)
    {
        cursor.setSource(input);
        document = domImpl.createDocument(null, null, null);
        currentNode = document;
    }
    
    bool enter()
    {
        if (cursor.atBeginning)
            return cursor.enter;
            
        if (cursor.getKind != XMLKind.ELEMENT_START)
            return false;
        
        if (!already_built)
        {
            auto elem = createCurrent;
            
            if (cursor.enter)
            {
                currentNode.appendChild(elem);
                currentNode = elem;
                return true;
            }
        }
        else if (cursor.enter)
        {
            already_built = false;
            currentNode = currentNode.lastChild;
            return true;
        }
        return false;
    }
    
    void exit()
    {
        if (currentNode)
            currentNode = currentNode.parentNode;
        already_built = false;
        cursor.exit;
    }
    
    bool next()
    {
        already_built = false;
        return cursor.next;
    }
    
    void build()
    {
        if (already_built || cursor.atBeginning)
            return;
            
        currentNode.appendChild(createCurrent);
        already_built = true;
    }
    
    bool buildRecursive()
    {
        if (enter)
        {
            while (buildRecursive) {}
            exit;
        }
        else
            build;
            
        return next;
    }
    
    private NodeType createCurrent()
    // TODO: namespace handling
    {
        switch (cursor.getKind) with(XMLKind)
        {
            case ELEMENT_START:
            case ELEMENT_EMPTY:
                auto elem = document.createElement(cursor.getName);
                foreach (attr; cursor.getAttributes)
                {
                    elem.setAttribute(attr.name, attr.value);
                }
                return elem;
            case TEXT:
                return document.createTextNode(cursor.getContent);
            case CDATA:
                return document.createCDATASection(cursor.getContent);
            case PROCESSING_INSTRUCTION:
                return document.createProcessingInstruction(cursor.getName, cursor.getContent);
            case COMMENT:
                return document.createComment(cursor.getContent);
            default:
                assert(0);
        }
    }
    
    auto getDocument() { return document; }
}

unittest
{
    import std.stdio;

    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.experimental.xml.cursor;
    import std.experimental.allocator.gc_allocator;
    import domimpl = std.experimental.xml.domimpl;
    
    alias CursorType = CopyingCursor!(Cursor!(Parser!(SliceLexer!string)));
    alias DOMImplType = domimpl.DOMImplementation!string;
    auto builder = DOMBuilder!(CursorType, DOMImplType)(new DOMImplType());
    
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
    
    builder.setSource(xml);
    builder.buildRecursive;
    auto doc = builder.getDocument;
    
    assert(doc.getElementsByTagName("ccc").length == 1);
    assert(doc.documentElement.getAttribute("xmlns:myns") == "something");
}
