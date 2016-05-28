
/++
+   This module tries to mimic the deprecated std.xml module, to ease transition.
+/
module std.experimental.xml.legacy;

import std.experimental.xml.cursor;
import std.experimental.xml.parser;
import std.experimental.xml.lexers;
import std.experimental.xml.interfaces;

alias ParserHandler = void delegate(ElementParser);
alias Handler = void delegate(string);

class ElementParser
{
    protected alias Cursor = XMLCursor!(Parser!(SliceLexer!string));

    private Cursor* cursor;
    
    ParserHandler[string] onStartTag;
    Handler onText;
    Handler onPI;
    
    protected this(Cursor* cur)
    {
        cursor = cur;
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
                        if (cursor.getName in onStartTag)
                        {
                            onStartTag[cursor.getName](new ElementParser(cursor));
                        }
                        break;
                    case XMLKind.PROCESSING_INSTRUCTION:
                        if (onPI != null)
                            onPI(cursor.getAll);
                        break;
                    case XMLKind.TEXT:
                        if (onText != null)
                            onText(cursor.getAll);
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
    Cursor cursor;
    
    this(string text)
    {
        super(&cursor);
        cursor.setSource(text);
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
    parser.onStartTag["aaa"] = (ElementParser elpar)
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
                assert(s.lineSplitter.map!"a.strip".array == ["Lots of Text!", "On multiple lines!", ""]);
            };
            elpar.parse;
        };
        elpar.onStartTag["ccc"] = (ElementParser elpar)
        {
            count += 64;
        };
        elpar.parse();
    };
    parser.parse();
    
    assert(count == 73);
}