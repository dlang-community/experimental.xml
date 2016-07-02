/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module std.experimental.xml.validation;

import std.experimental.xml.interfaces;
import std.experimental.xml.cursor;

enum ValidationEvent
{
    SOURCE,
    ENTER,
    EXIT,
    NEXT,
}

private struct ValidatingCursorImpl(P)
{
    static if (isLowLevelParser!P)
    {
        Cursor!P cursor;
    }
    else static if (isCursor!P)
    {
        P cursor;
    }
    alias CursorType = typeof(cursor);
    alias cursor this;
    
    this(Args...)(Args args)
    {
        cursor.__ctor(args);
    }
    
    void performBefore(ValidationEvent ev) {}
    void performAfter(ValidationEvent ev) {}
}

private struct ValidatingCursorImpl(P, T...)
{
    import std.algorithm: all;
    import std.ascii: isAlphaNum;
    
    static assert (T.length > 1);
    static assert (is(typeof(T[$-1]) == string), "Field name expected");
    static assert (T[$-1].all!isAlphaNum, "Invalid field name: " ~ T[$-1]);
    
    ValidatingCursorImpl!(P, T[0..$-2]) _p_parent;
    alias _p_parent this;
    
    private alias CurrType = T[$-2];
    static if (is(CurrType))
    {
        package CurrType _p_valid;
    }
    else static if (is(CurrType!(typeof(_p_parent))))
    {
        package CurrType!(typeof(_p_parent)) _p_valid;
    }
    else static assert(false, "Invalid validation type");
    
    this(Args...)(Args args)
        if (Args.length > 0)
    {
        static if (is(Args[$-1] == typeof(_p_valid)))
        {
            _p_parent = typeof(_p_parent)(args[0..$-1]);
            _p_valid = args[$-1];
        }
        else
        {
            _p_parent = typeof(_p_parent)(args);
            _p_valid = _p_valid.init;
        }
    }
    
    void performBefore(ValidationEvent ev)
    {
        _p_parent.performBefore(ev);
        static if (__traits(compiles, _p_valid.before(_p_parent, ev)))
            _p_valid.before(_p_parent, ev);
    }
    void performAfter(ValidationEvent ev)
    {
        _p_parent.performAfter(ev);
        static if (__traits(compiles, _p_valid.after(_p_parent, ev)))
            _p_valid.after(_p_parent, ev);
        else static if (__traits(compiles, _p_valid(_p_parent, ev)))
            _p_valid(_p_parent, ev);
    }
    
    mixin("@property ref typeof(_p_valid) " ~ T[$-1] ~ "() return { return _p_valid; }");
}

struct ValidatingCursor(P, T...)
{
    ValidatingCursorImpl!(P, T) _p_impl;
    alias _p_impl this;
    
    this(Args...)(Args args)
    {
        _p_impl = typeof(_p_impl)(args[0..$]);
    }
    
    void setSource(typeof(_p_impl).InputType input)
    {
        performBefore(ValidationEvent.SOURCE);
        _p_impl.setSource(input);
        performAfter(ValidationEvent.SOURCE);
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
        return ValidatingCursor!(P, TemplateArgsOf!(typeof(tuple!Names(args))))(args);
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
        void before(ref Cursor!ParserType cursor, ValidationEvent ev)
        {
            count++;
        }
    }
    struct Bar
    {
        void after(ref Cursor!ParserType cursor, ValidationEvent ev)
        {
            count++;
        }
    }
    void fun(ref Cursor!ParserType cursor, ValidationEvent ev)
    {
        if (ev == ValidationEvent.ENTER)
            count++;
    }
    
    auto validator = validatingCursor!(ParserType, "foo", "bar", "baz")(Foo(), Bar(), &fun);
    validator.performBefore(ValidationEvent.NEXT);
    validator.performAfter(ValidationEvent.NEXT);
    
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
    
    alias ErrorHandlerType = void delegate(ref CursorType, ref typeof(stack));
    ErrorHandlerType errorHandler;
    
    void before(ref CursorType cursor, ValidationEvent ev)
    {
        if (ev == ValidationEvent.ENTER)
            stack.insert(cursor.getName);
    }
    void after(ref CursorType cursor, ValidationEvent ev)
    {
        import std.experimental.xml.faststrings;
        
        if (ev == ValidationEvent.EXIT)
        {
            if (stack.empty || !fastEqual(stack.back, cursor.getName))
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
    
    auto validator = ValidatingCursor!(ParserType, ElementNestingValidator, "nestingValidator")();
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
    
    assert(count == 2);
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