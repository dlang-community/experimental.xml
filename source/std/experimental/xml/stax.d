/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++ This module implements a streaming XML parser.+/

module std.experimental.xml.stax;

import std.experimental.xml.interfaces;
import std.experimental.xml.cursor;

/++
+   Built on top of XMLCursor, the streaming parser adds to it the ability to 
+   be used as an InputRange of XML events starting from the current cursor position.
+   One can freely interleave the use of this component as Cursor and as an InputRange.
+/
struct StAXParser(T)
    if (isXMLCursor!T)
{
    /++
    +   The underlying XMLCursor methods are exposed, so that one can, for example,
    +   use the cursor API to reach a specific point of the document and then obtain
    +   an InputRange from that point.
    +/
    private T cursor;
    alias cursor this;
    
    alias StringType = cursor.StringType;

    /++ The type this StAXParser is an InputRange of. +/
    struct Node
    {
        /++ See function StAXParser.getKind(). +/
        XMLKind kind;
        
        /++ See function StAXParser.getLocalName(). +/
        StringType localName;
        
        /++ See function StAXParser.getPrefix(). +/
        StringType prefix;
        
        /++ See function StAXParser.getAttributes(). +/
        Attribute!StringType[] attributes;
        
        /++ See function StAXParser.getNamespaceDefinitions(). +/
        NamespaceDeclaration!StringType[] namespaceDefinitions;
        
        /++ See function StAXParser.getText(). +/
        StringType text;
    }
    
    bool empty()
    {
        return cursor.documentEnd();
    }
    Node front()
    {
        Node result;
        result.kind = getKind();
        result.localName = getLocalName();
        result.prefix = getPrefix();
        result.attributes = getAttributes();
        result.namespaceDefinitions = getNamespaceDefinitions();
        result.text = getText();
        return result;
    }
    void popFront()
    {
        if (hasChildren())
            enter();
        else if (!next())
            exit();
    }
    
    static if (isSaveableXMLCursor!T)
        auto save() const
        {
            return StAXParser(cursor.save);
        }
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.experimental.xml.cursor;
    import std.string: splitLines;
    
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
    
    auto stax = StAXParser!(XMLCursor!(Parser!(SliceLexer!string)))();
    stax.setSource(xml);
    
    // <?xml encoding = "utf-8" ?>
    assert(stax.front.kind == XMLKind.DOCUMENT);
    assert(stax.front.prefix == "");
    assert(stax.front.localName == "xml");
    assert(stax.front.attributes == [Attribute!string("", "encoding", "utf-8")]);
    assert(stax.front.namespaceDefinitions == []);
    assert(stax.front.text == []);
    
    stax.popFront;
        // <aaa xmlns:myns="something">
        assert(stax.front.kind == XMLKind.ELEMENT_START);
        assert(stax.front.prefix == "");
        assert(stax.front.localName == "aaa");
        assert(stax.front.attributes == []);
        assert(stax.front.namespaceDefinitions == [NamespaceDeclaration!string("myns", "something")]);
        assert(stax.front.text == []);
        
        stax.popFront;
            // <myns:bbb myns:att='>'>
            assert(stax.front.kind == XMLKind.ELEMENT_START);
            assert(stax.front.prefix == "myns");
            assert(stax.front.localName == "bbb");
            assert(stax.front.attributes == [Attribute!string("myns", "att", ">")]);
            assert(stax.front.namespaceDefinitions == []);
            assert(stax.front.text == []);
            
            stax.popFront;
                // <!-- lol -->
                assert(stax.front.kind == XMLKind.COMMENT);
                assert(stax.front.prefix == "");
                assert(stax.front.localName == "");
                assert(stax.front.attributes == []);
                assert(stax.front.namespaceDefinitions == []);
                assert(stax.front.text == " lol ");
                
                stax.popFront;
                // Lots of Text!
                // On multiple lines!
                assert(stax.front.kind == XMLKind.TEXT);
                assert(stax.front.prefix == "");
                assert(stax.front.localName == "");
                assert(stax.front.attributes == []);
                assert(stax.front.namespaceDefinitions == []);
                // use splitlines so the unittest does not depend on the newline policy of this file
                assert(stax.front.text.splitLines == ["Lots of Text!", "            On multiple lines!", "        "]);
                
            stax.popFront;
            
            // </myns:bbb>
            assert(stax.front.kind == XMLKind.ELEMENT_END);
            assert(stax.front.prefix == "myns");
            assert(stax.front.localName == "bbb");
            assert(stax.front.attributes == []);
            assert(stax.front.namespaceDefinitions == []);
            assert(stax.front.text == []);
            
            stax.popFront;
            // <<![CDATA[ Ciaone! ]]>
            assert(stax.front.kind == XMLKind.TEXT);
            assert(stax.front.prefix == "");
            assert(stax.front.localName == "");
            assert(stax.front.attributes == []);
            assert(stax.front.namespaceDefinitions == []);
            assert(stax.front.text == " Ciaone! ");
            
            stax.popFront;
            // <ccc/>
            assert(stax.front.kind == XMLKind.ELEMENT_EMPTY);
            assert(stax.front.prefix == "");
            assert(stax.front.localName == "ccc");
            assert(stax.front.attributes == []);
            assert(stax.front.namespaceDefinitions == []);
            assert(stax.front.text == []);
            
        stax.popFront;
        
        // </aaa>
        assert(stax.front.kind == XMLKind.ELEMENT_END);
        assert(stax.front.prefix == "");
        assert(stax.front.localName == "aaa");
        assert(stax.front.attributes == []);
        assert(stax.front.namespaceDefinitions == []);
        assert(stax.front.text == []);
        
    stax.popFront;
    
    assert(stax.empty);
}