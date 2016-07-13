/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

// TODO: write an in-depth explanation of this module, how to create validations,
// how validations should behave, etc...

module std.experimental.xml.validation;

import std.experimental.xml.interfaces;
import std.experimental.xml.cursor;

enum ValidationEvent
{
    START,
    ENTER,
    NEXT,
    EXIT,
    END,
}

private struct ValidatingCursorImpl(P, Alloc)
{
    static if (isLowLevelParser!P)
    {
        Cursor!P cursor;
    }
    else static if (isCursor!P)
    {
        P cursor;
    }
    else static assert(0, "Invalid parser/cursor parameter for ValidatingCursor");
    
    alias CursorType = typeof(cursor);
    alias cursor this;
    
    this(Args...)(Args args)
    {
        cursor.__ctor(args);
    }
    
    bool performBefore(ValidationEvent ev) { return true; }
    bool performAfter(ValidationEvent ev) { return true; }
}

private struct ValidatingCursorImpl(P, Alloc, Validations...)
{
    import std.algorithm: all;
    import std.ascii: isAlphaNum;
    
    static assert(Validations.length > 1, "wrong number of parameters");
    static assert(is(typeof(Validations[1]) == string), "missing field name");
    
    private alias T = Validations[0];
    private enum string name = Validations[1];
    
    static assert(name.all!isAlphaNum, "Invalid field name: " ~ name);
    
    ValidatingCursorImpl!(P, Alloc, Validations[2..$]) _p_parent;
    alias _p_parent this;
    
    static if (is(T))
    {
        package T _p_valid;
    }
    else static if (is(T!(typeof(_p_parent))))
    {
        package T!(typeof(_p_parent)) _p_valid;
    }
    else static assert(0, "Invalid validation type");
    
    this(Args...)(Args args)
        if (Args.length > 0)
    {
        static if (is(Args[0] == typeof(_p_valid)))
        {
            _p_parent = typeof(_p_parent)(args[1..$]);
            _p_valid = args[0];
        }
        else
        {
            _p_parent = typeof(_p_parent)(args);
            _p_valid = _p_valid.init;
        }
    }
    
    auto getValidation(alias Valid)()
    {
        static if (__traits(isSame, T, Valid) || is(typeof(_p_valid) == Valid))
        {
            return _p_valid;
        }
        else return _p_parent.getValidation!Valid;
    }
    
    bool performBefore(ValidationEvent ev)
    {
        static if (__traits(compiles, cast(bool)_p_valid.before(_p_parent, ev)))
            return cast(bool)_p_valid.before(_p_parent, ev);
        else
            return _p_parent.performBefore(ev);
    }
    bool performAfter(ValidationEvent ev)
    {
        static if (__traits(compiles, cast(bool)_p_valid.after(_p_parent, ev)))
            return cast(bool)_p_valid.after(_p_parent, ev);
        else static if (__traits(compiles, cast(bool)_p_valid(_p_parent, ev)))
            return cast(bool)_p_valid(_p_parent, ev);
        else
            return _p_parent.performAfter(ev);
    }
    
    mixin("@property ref typeof(_p_valid) " ~ name ~ "() return { return _p_valid; }");
}

struct ValidatingCursor(P, Alloc, T...)
{
    ValidatingCursorImpl!(P, Alloc, T) _p_impl;
    alias _p_impl this;
    
    this(Args...)(Args args)
    {
        _p_impl = typeof(_p_impl)(args);
    }
    
    void setSource(typeof(_p_impl).InputType input)
    {
        performBefore(ValidationEvent.START);
        _p_impl.setSource(input);
        performAfter(ValidationEvent.START);
    }
    void enter()
    {
        performBefore(ValidationEvent.ENTER);
        _p_impl.enter;
        performAfter(ValidationEvent.ENTER);
    }
    auto next()
    {
        performBefore(ValidationEvent.NEXT);
        if (_p_impl.next)
        {
            performAfter(ValidationEvent.NEXT);
            return true;
        }
        return false;
    }
    void exit()
    {
        performBefore(ValidationEvent.EXIT);
        _p_impl.exit;
        performAfter(ValidationEvent.EXIT);
    }
}

template validatingCursor(P, Names...)
{
    import std.typecons: tuple;
    import std.traits: TemplateArgsOf;
    auto validatingCursor(Args...)(Args args)
    {
        return ValidatingCursor!(P, void, TemplateArgsOf!(typeof(tuple!Names(args))))(args);
    }
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    
    alias ParserType = Parser!(SliceLexer!string);
    
    auto count = 0;
    
    struct Foo
    {
        int* count;
        this(ref int count)
        {
            this.count = &count;
        }
        bool before(Cursor)(ref Cursor cursor, ValidationEvent ev)
        {
            (*count)++;
            return cursor.performBefore(ev);
        }
        bool after(Cursor)(ref Cursor cursor, ValidationEvent ev)
        {
            (*count)++;
            return cursor.performAfter(ev);
        }
    }
    struct Bar
    {
        int* count;
        this(ref int count)
        {
            this.count = &count;
        }
        bool after(Cursor)(ref Cursor cursor, ValidationEvent ev)
        {
            if (cursor.performAfter(ev))
            {
                (*count)++;
                return true;
            }
            return false;
        }
    }
    bool fun(ref Cursor!ParserType cursor, ValidationEvent ev)
    {
        if (ev == ValidationEvent.ENTER)
            count++;
        return false;
    }
    
    auto validator = validatingCursor!(ParserType, "foo", "bar", "baz")(Foo(count), Bar(count), &fun);
    
    assert(validator.performBefore(ValidationEvent.NEXT));
    assert(!validator.performAfter(ValidationEvent.NEXT));
    
    Cursor!ParserType cursor;
    auto myfun = validator.baz;
    myfun(cursor, ValidationEvent.ENTER);
    
    assert(count == 3);
}

struct ElementNestingValidator(CursorType)
{
    import std.experimental.xml.interfaces;
    
    alias StringType = CursorType.StringType;
 
    import std.container.array;   
    Array!StringType stack;
    
    alias ErrorHandlerType = bool delegate(ref CursorType, ref typeof(stack));
    ErrorHandlerType errorHandler;
    
    bool before(ref CursorType cursor, ValidationEvent ev)
    {
        if (cursor.performBefore(ev))
        {
            if (ev == ValidationEvent.ENTER && cursor.getKind != XMLKind.DOCUMENT)
                stack.insert(cursor.getName);
            return true;
        }
        return false;
    }
    bool after(ref CursorType cursor, ValidationEvent ev)
    {
        import std.experimental.xml.faststrings;
        
        if (cursor.performAfter(ev))
        {
            if (ev == ValidationEvent.EXIT)
            {
                if (stack.empty)
                {
                    if (!cursor.documentEnd)
                    {
                        if (errorHandler != null)
                            return errorHandler(cursor, stack);
                        else
                            assert(0);
                    }
                }
                else
                {
                    if (!fastEqual(stack.back, cursor.getName))
                    {
                        if (errorHandler != null)
                            return errorHandler(cursor, stack);
                        else
                            assert(0);
                    }
                    else
                        stack.removeBack();
                }
            }
            return true;
        }
        return false;
    }
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    
    alias ParserType = Parser!(SliceLexer!string);
    
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
    
    auto validator = ValidatingCursor!(ParserType, void, ElementNestingValidator, "nestingValidator")();
    validator.setSource(xml);
    
    int count = 0;
    validator.nestingValidator.errorHandler = (ref cursor, ref stack)
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
    assert(validator.nestingValidator.errorHandler != null);
    
    void inspectOneLevel(T)(ref T cursor)
    {
        do
        {
            if (cursor.hasChildren())
            {
                cursor.enter();
                inspectOneLevel(cursor);
                cursor.exit();
            }
        }
        while (cursor.next());
    }
    inspectOneLevel(validator);
    
    assert(count == 1);
}

struct ParentStackSaver(CursorType)
{
    import std.experimental.xml.interfaces;
    import std.experimental.allocator;
    import std.experimental.allocator.mallocator;

    alias StringType = CursorType.StringType;
    struct Node
    {
        Node* parent;
        XMLKind kind;
        StringType name, localName, prefix;
        StringType text;
        Attribute!StringType[] attributes;
        NamespaceDeclaration!StringType[] namespaces;
    }
    Node* parent;
    
    bool before(ref CursorType cursor, ValidationEvent ev)
    {
        if (cursor.performBefore(ev))
        {
            if (ev == ValidationEvent.ENTER)
            {
                Node* node = Mallocator.instance.make!Node;
                node.kind = cursor.getKind();
                node.name = cursor.getName;
                node.localName = cursor.getLocalName();
                node.prefix = cursor.getPrefix();
                node.text = cursor.getText();
                node.attributes = cursor.getAttributes();
                node.namespaces = cursor.getNamespaceDefinitions();
                node.parent = parent;
                parent = node;
            }
            return true;
        }
        return false;
    }
    bool after(ref CursorType cursor, ValidationEvent ev)
    {
        if (cursor.performAfter(ev))
        {
            if (ev == ValidationEvent.EXIT)
            {
                auto node = parent;
                parent = parent.parent;
                Mallocator.instance.dispose(parent);
            }
            return true;
        }
        return false;
    }
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    
    alias ParserType = Parser!(SliceLexer!string);
    
    auto xml = q{
        <?xml?>
        <aaa>
            <bbb>
                <ccc>
            </bbb>
            <ddd>
            </ddd>
        </aaa>
    };
    
    auto cursor = ValidatingCursor!(ParserType, void, ParentStackSaver, "p")();
    cursor.setSource(xml);
    
    cursor.enter();
        assert(cursor.p.parent.kind == XMLKind.DOCUMENT);
        cursor.enter();
            assert(cursor.p.parent.kind == XMLKind.ELEMENT_START);
            assert(cursor.p.parent.parent.kind == XMLKind.DOCUMENT);
        cursor.exit();
        assert(cursor.p.parent.kind == XMLKind.DOCUMENT);
    cursor.exit();
    assert(cursor.documentEnd);
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

struct CheckXMLNames(CursorType)
{
    alias StringType = CursorType.StringType;
    bool delegate(StringType) onInvalidTagName;
    bool delegate(StringType) onInvalidAttrName;
    bool delegate(StringType) onInvalidNSPrefix;
    
    bool after(ref CursorType cursor, ValidationEvent ev)
    {
        if (ev != ValidationEvent.ENTER && ev != ValidationEvent.NEXT)
            return cursor.performAfter(ev);
        if (cursor.performAfter(ev))
        {
            import std.algorithm: all;
            auto name = cursor.getName;
            if ((!name[0].isValidXMLNameStart || !name.all!isValidXMLNameChar) && !onInvalidTagName(name))
                return false;
            foreach (attr; cursor.getAttributes)
                if ((!attr.name[0].isValidXMLNameStart || !attr.name.all!isValidXMLNameChar) && !onInvalidAttrName(attr.name))
                    return false;
            foreach (ns; cursor.getNamespaceDefinitions)
                if ((!ns.prefix[0].isValidXMLNameStart || !ns.prefix.all!isValidXMLNameChar) && !onInvalidNSPrefix(ns.prefix))
                    return false;
            return true;
        }
        return false;
    }
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    
    alias ParserType = Parser!(SliceLexer!string);
    
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
    
    auto cursor = ValidatingCursor!(ParserType, void, CheckXMLNames, "nameChecker")();
    cursor.setSource(xml);
    cursor.nameChecker.onInvalidTagName = (s) { count++; return true; };
    cursor.nameChecker.onInvalidAttrName = (s) { count++; return true; };
    cursor.nameChecker.onInvalidNSPrefix = (s) { count++; return true; };
    
    void inspectOneLevel(T)(ref T cursor)
    {
        do
        {
            if (cursor.hasChildren())
            {
                cursor.enter();
                inspectOneLevel(cursor);
                cursor.exit();
            }
        }
        while (cursor.next());
    }
    inspectOneLevel(cursor);
    
    assert(count == 3);
}