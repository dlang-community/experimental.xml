/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

// TODO: write an in-depth explanation of this module, how to create validations,
// how validations should behave, etc...

/++
+   Authors:
+   Lodovico Giaretta
+
+   License:
+   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
+
+   Copyright:
+   Copyright Lodovico Giaretta 2016 --
+/

module std.experimental.xml.validation;

import std.experimental.xml.interfaces;

struct ElementNestingValidator(CursorType)
    if (isCursor!CursorType)
{
    import std.experimental.xml.interfaces;
    
    alias StringType = CursorType.StringType;
 
    import std.container.array;   
    private Array!StringType stack;
    
    alias ErrorHandlerType = bool delegate(ref CursorType, ref typeof(stack));
    ErrorHandlerType errorHandler;
    
    private CursorType cursor;
    alias cursor this;
    
    this(Args...)(Args args)
    {
        cursor = CursorType(args);
    }
    
    bool enter()
    {
        if (cursor.getKind == XMLKind.ELEMENT_START)
        {
            stack.insertBack(cursor.getName);
            if (!cursor.enter)
            {
                stack.removeBack;
                return false;
            }
            return true;
        }
        return cursor.enter;
    }
    void exit()
    {
        cursor.exit();
        if (cursor.getKind == XMLKind.ELEMENT_END)
        {
            if (stack.empty)
            {
                if (!cursor.documentEnd)
                {
                    if (errorHandler != null)
                        errorHandler(cursor, stack);
                    else
                        assert(0);
                }
            }
            else
            {
                import std.experimental.xml.faststrings;
        
                if (!fastEqual(stack.back, cursor.getName))
                {
                    if (errorHandler != null)
                        errorHandler(cursor, stack);
                    else
                        assert(0);
                }
                else
                    stack.removeBack();
            }
        }
    }
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.experimental.xml.cursor;
    
    auto xml = q{
        <?xml?>
        <aaa>
            <eee>
                <bbb>
                    <ccc>
                </bbb>
                <ddd>
                </ddd>
            </eee>
            <fff>
            </fff>
        </aaa>
    };
    
    auto validator = ElementNestingValidator!(Cursor!(Parser!(SliceLexer!string)))();
    validator.setSource(xml);
    
    int count = 0;
    validator.errorHandler = (ref cursor, ref stack)
    {
        import std.algorithm: canFind;
        count++;
        if (canFind(stack[], cursor.getName()))
            do
            {
                stack.removeBack();
            }
            while (stack.back != cursor.getName());
        stack.removeBack();
        return true;
    };
    assert(validator.errorHandler != null);
    
    void inspectOneLevel(T)(ref T cursor)
    {
        do
        {
            if (cursor.enter)
            {
                inspectOneLevel(cursor);
                cursor.exit();
            }
        }
        while (cursor.next());
    }
    inspectOneLevel(validator);
    
    assert(count == 1);
}

pure nothrow @nogc @safe bool isValidXMLCharacter10(dchar c)
{
    return c == '\r' || c == '\n' || c == '\t'
        || (0x20 <= c && c <= 0xD7FF)
        || (0xE000 <= c && c <= 0xFFFD)
        || (0x10000 <= c && c <= 0x10FFFF);
}

pure nothrow @nogc @safe bool isValidXMLCharacter11(dchar c)
{
    return (1 <= c && c <= 0xD7FF)
        || (0xE000 <= c && c <= 0xFFFD)
        || (0x10000 <= c && c <= 0x10FFFF);
}

pure nothrow @nogc @safe bool isValidXMLNameStart(dchar c)
{
    return c == ':'
        || ('A' <= c && c <= 'Z')
        || c == '_'
        || ('a' <= c && c <= 'z')
        || (0xC0 <= c && c <= 0x2FF && c != 0xD7 && c != 0xF7)
        || (0x370 <= c && c <= 0x1FFF && c != 0x37E)
        || c == 0x200C
        || c == 0x200D
        || (0x2070 <= c && c <= 0x218F)
        || (0x2C00 <= c && c <= 0x2FEF)
        || (0x3001 <= c && c <= 0xD7FF)
        || (0xF900 <= c && c <= 0xFDCF)
        || (0xFDF0 <= c && c <= 0xEFFFF && c != 0xFFFE && c != 0xFFFF);
}

pure nothrow @nogc @safe bool isValidXMLNameChar(dchar c)
{
    return isValidXMLNameStart(c)
        || c == '-'
        || c == '.'
        || ('0' <= c && c <= '9')
        || c == 0xB7
        || (0x300 <= c && c <= 0x36F)
        || (0x203F <= c && c <= 2040);
}

pure nothrow @nogc @safe bool isValidXMLPublicIdCharacter(dchar c)
{
    import std.string: indexOf;
    return c == ' '
        || c == '\n'
        || c == '\r'
        || ('a' <= c && c <= 'z')
        || ('A' <= c && c <= 'Z')
        || ('0' <= c && c <= '9')
        || "-'()+,./:=?;!*#@$_%".indexOf(c) != -1;
}

struct CheckXMLNames(CursorType, InvalidTagHandler, InvalidAttrHandler)
    if (isCursor!CursorType)
{
    alias StringType = CursorType.StringType;
    InvalidTagHandler onInvalidTagName;
    InvalidAttrHandler onInvalidAttrName;
    
    CursorType cursor;
    alias cursor this;
    
    auto getName()
    {
        import std.algorithm: all;
        
        auto name = cursor.getName;
        if (!name[0].isValidXMLNameStart || !name.all!isValidXMLNameChar)
            onInvalidTagName(name);
        return name;
    }
    
    auto getAttributes()
    {
        struct CheckedAttributes
        {
            typeof(onInvalidAttrName) callback;
            typeof(cursor.getAttributes()) attrs;
            alias attrs this;
            
            auto front()
            {
                import std.algorithm: all;
        
                auto attr = attrs.front;
                if (!attr.name[0].isValidXMLNameStart || !attr.name.all!isValidXMLNameChar)
                    callback(attr.name);
                return attr;
            }
        }
        return CheckedAttributes(onInvalidAttrName, cursor.getAttributes);
    }
}
auto checkXMLNames(CursorType, InvalidTagHandler, InvalidAttrHandler)
                  (auto ref CursorType cursor,
                   InvalidTagHandler tagHandler = (CursorType.StringType s) {},
                   InvalidAttrHandler attrHandler = (CursorType.StringType s) {})
{
    auto res = CheckXMLNames!(CursorType, InvalidTagHandler, InvalidAttrHandler)();
    res.cursor = cursor;
    res.onInvalidTagName = tagHandler;
    res.onInvalidAttrName = attrHandler;
    return res;
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.experimental.xml.cursor;
    import std.stdio;
    
    auto xml = q{
        <?xml?>
        <aa.a at;t = "hi!">
            <bbb>
                <-ccc>
            </bbb>
            <dd-d xmlns:,="http://foo.bar/baz">
            </dd-d>
        </aa.a>
    };
    
    int count = 0;
    
    auto cursor = checkXMLNames(Cursor!(Parser!(SliceLexer!string))(),
                                (string s) { count++; },
                                (string s) { count++; });
    cursor.setSource(xml);
    
    void inspectOneLevel(T)(ref T cursor)
    {
        import std.array;
        do
        {
            auto name = cursor.getName;
            auto attrs = cursor.getAttributes.array;
            if (cursor.enter)
            {
                inspectOneLevel(cursor);
                cursor.exit();
            }
        }
        while (cursor.next);
    }
    inspectOneLevel(cursor);
    
    assert(count == 3);
}