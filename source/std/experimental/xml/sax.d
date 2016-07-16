/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module std.experimental.xml.sax;

import std.experimental.xml.interfaces;
import std.experimental.xml.cursor;

struct SAXParser(T, alias H)
    if (isCursor!T)
{
    static if (__traits(isTemplate, H))
        alias HandlerType = H!T;
    else
        alias HandlerType = H;
        
    private T cursor;
    public HandlerType handler;
    
    /++
    +   Initializes this parser (and the underlying low level one) with the given input.
    +/
    void setSource(T.InputType input)
    {
        cursor.setSource(input);
    }
    
    static if (isSaveableCursor!T)
    {
        auto save()
        {
            auto result = this;
            result.cursor = cursor.save;
            return result;
        }
    }
    
    /++
    +   Processes the entire document; every time a node of
    +   Kind XXX is found, the corresponding method onXXX(this)
    +   of the handler is called, if it exists.
    +/
    void processDocument()
    {
        while (!cursor.documentEnd)
        {
            switch (cursor.getKind)
            {
                case XMLKind.DOCUMENT:
                    static if (__traits(compiles, handler.onDocument(cursor)))
                        handler.onDocument(cursor);
                    break;
                case XMLKind.ELEMENT_START:
                    static if (__traits(compiles, handler.onElementStart(cursor)))
                        handler.onElementStart(cursor);
                    break;
                case XMLKind.ELEMENT_END:
                    static if (__traits(compiles, handler.onElementEnd(cursor)))
                        handler.onElementEnd(cursor);
                    break;
                case XMLKind.ELEMENT_EMPTY:
                    static if (__traits(compiles, handler.onElementEmpty(cursor)))
                        handler.onElementEmpty(cursor);
                    break;
                case XMLKind.TEXT:
                    static if (__traits(compiles, handler.onText(cursor)))
                        handler.onText(cursor);
                    break;
                case XMLKind.COMMENT:
                    static if (__traits(compiles, handler.onComment(cursor)))
                        handler.onComment(cursor);
                    break;
                case XMLKind.PROCESSING_INSTRUCTION:
                    static if (__traits(compiles, handler.onProcessingInstruction(cursor)))
                        handler.onProcessingInstruction(cursor);
                    break;
                default: break;
            }
            
            if (cursor.hasChildren)
                cursor.enter;
            else if (!cursor.next)
                cursor.exit;
        }
    }
}

unittest
{
    import std.experimental.xml.parser;
    import std.experimental.xml.lexers;

    dstring xml = q{
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
    
    struct MyHandler(T)
    {
        int max_nesting;
        int current_nesting;
        int total_invocations;
        
        void onElementStart(ref T node)
        {
            total_invocations++;
            if (node.hasChildren)
            {
                current_nesting++;
                if (current_nesting > max_nesting)
                    max_nesting = current_nesting;
            }
        }
        void onElementEnd(ref T node)
        {
            total_invocations++;
            current_nesting--;
        }
        void onElementEmpty(ref T node) { total_invocations++; }
        void onProcessingInstruction(ref T node) { total_invocations++; }
        void onText(ref T node) { total_invocations++; }
        void onDocument(ref T node)
        {
            assert(node.getAttributes == [Attribute!dstring("", "encoding", "utf-8")]);
            total_invocations++;
        }
        void onComment(ref T node)
        {
            assert(node.getText == " lol ");
            total_invocations++;
        }
    }
    
    auto parser = SAXParser!(Cursor!(Parser!(SliceLexer!dstring)), MyHandler)();
    parser.setSource(xml);
    
    parser.processDocument();
    
    assert(parser.handler.max_nesting == 2);
    assert(parser.handler.current_nesting == 0);
    assert(parser.handler.total_invocations == 9);
}