/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module tries to mimic the deprecated std.xml module, to ease transition.
+/
module std.experimental.xml.legacy;

import std.experimental.xml.cursor;
import std.experimental.xml.parser;
import std.experimental.xml.lexers;
import std.experimental.xml.interfaces;

class ElementParser
{
    import std.experimental.allocator.gc_allocator;
    private alias CursorType = Cursor!(Parser!(SliceLexer!string), shared(GCAllocator), CursorOptions.DontConflateCDATA);

    alias ParserHandler = void delegate(ElementParser);
    alias ElementHandler = void delegate(in Element);
    alias Handler = void delegate(string);

    private CursorType* cursor;
    
    ParserHandler[string] onStartTag;
    ElementHandler[string] onEndTag;
    Handler onText;
    Handler onPI;
    Handler onComment;
    Handler onCData;
    Handler onTextRaw;
    
    Tag _tag;
    @property const(Tag) tag() const
    {
        return _tag;
    }
    
    private this(CursorType* cur)
    {
        cursor = cur;
        _tag =  new Tag(cursor.getName);
        foreach (attr; cursor.getAttributes)
            _tag.attributes[attr.prefix ~ ":" ~ attr.name] = attr.value;
    }
    
    void parse()
    {
        if (cursor.hasChildren)
        {
            cursor.enter();
            do
            {
                switch (cursor.getKind)
                {
                    case XMLKind.ELEMENT_START:
                    case XMLKind.ELEMENT_EMPTY:
                        if (cursor.getName in onStartTag || null in onStartTag)
                        {
                            CursorType copy;
                            if (cursor.getName in onEndTag || null in onEndTag)
                                copy = cursor.save;
                            
                            if (cursor.getName in onStartTag)
                                onStartTag[cursor.getName](new ElementParser(cursor));
                            else
                                onStartTag[null](new ElementParser(cursor));
                            
                            if (cursor.getName in onEndTag)
                                onEndTag[cursor.getName](new Element(new ElementParser(&copy)));
                            else if (null in onEndTag)
                                onEndTag[null](new Element(new ElementParser(&copy)));
                        }
                        else if (cursor.getName in onEndTag)
                            onEndTag[cursor.getName](new Element(new ElementParser(cursor)));
                        else if (null in onEndTag)
                            onEndTag[null](new Element(new ElementParser(cursor)));
                        break;
                    case XMLKind.PROCESSING_INSTRUCTION:
                        if (onPI != null)
                            onPI(cursor.getAll);
                        break;
                    case XMLKind.TEXT:
                        if (onTextRaw != null)
                            onTextRaw(cursor.getAll);
                        if (onText != null)
                            onText(cursor.getAll);
                        break;
                    case XMLKind.COMMENT:
                        if (onComment != null)
                            onComment(cursor.getAll);
                        break;
                    case XMLKind.CDATA:
                        if (onCData != null)
                            onCData(cursor.getAll);
                        break;
                    default:
                        break;  
                }
            } while (cursor.next());
            cursor.exit();
        }
    }
}

class DocumentParser: ElementParser
{
    CursorType cursor;
    
    this(string text)
    {
        auto handler = delegate(ref CursorType cur, CursorType.Error err) {};
        cursor.setErrorHandler(handler);
        cursor.setSource(text);
        super(&cursor);
    }
}

enum TagType
{
    START,
    END,
    EMPTY
}

class Tag
{
    TagType type;
    string name;
    string[string] attributes;
    
    this(string name, TagType type = TagType.START)
    {
        this.name = name;
        this.type = type;
    }
}

unittest
{
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
    
    int count = 0;
    
    auto parser = new DocumentParser(xml);
    parser.onStartTag[null] = (ElementParser elpar)
    {
        count += 1;
        elpar.onStartTag["myns:bbb"] = (ElementParser elpar)
        {
            count += 8;
            elpar.onText = (string s)
            {
                import std.string: lineSplitter, strip;
                import std.algorithm: map;
                import std.array: array;
                // split and strip to ensure it does not depend on indentation or line endings
                assert(s.lineSplitter.map!"a.strip".array == ["Lots of Text!", "On multiple lines!", ""]);
            };
            elpar.onComment = (string s)
            {
                assert(s == " lol ");
            };
            elpar.parse;
        };
        elpar.onStartTag["ccc"] = (ElementParser elpar)
        {
            count += 64;
        };
        elpar.onCData = (string s)
        {
            assert(s == " Ciaone! ");
        };
        elpar.parse();
    };
    parser.parse();
    
    assert(count == 73);
}

class Item
{
}

class Element: Item
{
    Item[] items;
    Text[] texts;
    CData[] cdatas;
    Comment[] comments;
    ProcessingInstruction[] pis;
    Element[] elements;
    
    Tag tag;
    
    this(string name, string interior = null)
    {
        tag = new Tag(name);
        if (interior != null)
            opOpAssign!"~"(new Text(interior));
    }
    
    this(const Tag tag_)
    {
        tag = new Tag(tag_.name);
        foreach (k,v; tag_.attributes)
            tag.attributes[k] = v;
    }
    
    private this(ElementParser parser)
    {
        this(parser.tag);
        parser.onText = (string s) { opOpAssign!"~"(new Text(s)); };
        parser.onCData = (string s) { opOpAssign!"~"(new CData(s)); };
        parser.onComment = (string s) { opOpAssign!"~"(new Comment(s)); };
        parser.onPI = (string s) { opOpAssign!"~"(new ProcessingInstruction(s)); };
        parser.onStartTag[null] = (ElementParser parser) { opOpAssign!"~"(new Element(parser)); };
        parser.parse;
    }
    
    private this()
    {
    }
    private void parse(ElementParser parser)
    {
        tag = new Tag(parser.tag.name);
        foreach (k,v; parser.tag.attributes)
            tag.attributes[k] = v;
        parser.onText = (string s) { opOpAssign!"~"(new Text(s)); };
        parser.onCData = (string s) { opOpAssign!"~"(new CData(s)); };
        parser.onComment = (string s) { opOpAssign!"~"(new Comment(s)); };
        parser.onPI = (string s) { opOpAssign!"~"(new ProcessingInstruction(s)); };
        parser.onStartTag[null] = (ElementParser parser) { opOpAssign!"~"(new Element(parser)); };
        parser.parse;
    }
    
    void opOpAssign(string s)(Text item)
        if (s == "~")
    {
        texts ~= item;
        items ~= item;
    }
    
    void opOpAssign(string s)(CData item)
        if (s == "~")
    {
        cdatas ~= item;
        items ~= item;
    }
    
    void opOpAssign(string s)(Comment item)
        if (s == "~")
    {
        comments ~= item;
        items ~= item;
    }
    
    void opOpAssign(string s)(ProcessingInstruction item)
        if (s == "~")
    {
        pis ~= item;
        items ~= item;
    }
    
    void opOpAssign(string s)(Element item)
        if (s == "~")
    {
        elements ~= item;
        items ~= item;
    }
}

class Text: Item
{
    private string content;
    
    this(string content)
    {
        this.content = content;
    }
}

class Comment: Item
{
    private string content;
    
    this(string content)
    {
        this.content = content;
    }
}

class CData: Item
{
    private string content;
    
    this(string content)
    {
        this.content = content;
    }
}

class ProcessingInstruction: Item
{
    private string content;
    
    this(string content)
    {
        this.content = content;
    }
}

class Document: Element
{
    string prolog;
    string epilog;
    
    this(const Tag tag)
    {
        super(tag);
        prolog = "<?xml version=\"1.0\"?>";
        epilog = "";
    }
    
    this(string s)
    {
        auto parser = new DocumentParser(s);
        parser.onStartTag[null] = (ElementParser parser)
        {
            auto prologEnd = (parser.cursor.getAll.ptr - s.ptr) - 1;
            prolog = s[0..prologEnd];
            super.parse(parser);
        };
        parser.parse;
    }
}

unittest
{
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
    
    auto dom = new Document(xml);
    
    import std.string: strip;
    assert(dom.prolog.strip == "<?xml encoding = \"utf-8\" ?>");
    assert(dom.tag.name == "aaa");
    assert(dom.items.length == 3);
    assert(dom.elements.length == 2);
    assert(dom.cdatas.length == 1);
}
