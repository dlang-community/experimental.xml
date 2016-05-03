
module std.experimental.xml.validation;

import std.experimental.xml.cursor;
import std.typecons: Tuple;

template applyCursorType(CursorType)
{
    template applyCursorType(string s)
    {
        enum string applyCursorType = s;
    }
    template applyCursorType(T)
    {
        alias applyCursorType = T;
    }
    template applyCursorType(alias T)
    {
        alias applyCursorType = T!CursorType;
    }
}

struct ValidatingCursor(P, T...)
{
    XMLCursor!P cursor;
    alias CursorType = typeof(cursor);
    
    import std.meta: staticMap, staticIndexOf;
    private Tuple!(staticMap!(applyCursorType!CursorType, T)) validations;
    
    ref auto opDispatch(string s, T...)(T args)
    {
        static if (staticIndexOf!(s, validations.fieldNames) != -1)    
            mixin("return validations." ~ s ~ ";");
        else
            mixin("return cursor." ~ s ~ "(args);");
    }
    
    void performValidations()
    {
        foreach (ref valid; validations)
            static if (__traits(compiles, valid.validate(cursor)))
                valid.validate(cursor);
            else if (__traits(compiles, valid(cursor)))
                valid(cursor);
            else
                assert(0);
    }
    
    void enter()
    {
        cursor.enter();
        performValidations();
    }
    void exit()
    {
        cursor.exit();
        performValidations();
    }
    bool next()
    {
        auto result = cursor.next();
        performValidations();
        return result;
    }
}

template validatingCursor(P, Names...)
{
    import std.typecons: tuple;
    import std.traits: TemplateArgsOf;
    auto validatingCursor(Args...)(Args args)
    {
        return ValidatingCursor!(P, TemplateArgsOf!(typeof(tuple!Names(args))))(XMLCursor!P(), tuple!Names(args));
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
        void validate(ref XMLCursor!ParserType cursor)
        {
            count++;
        }
    }
    struct Bar
    {
        void validate(ref XMLCursor!ParserType cursor)
        {
            count++;
        }
    }
    void fun(ref XMLCursor!ParserType cursor)
    {
        count++;
    }
    
    auto validator = validatingCursor!(ParserType, "foo", "bar", "baz")(Foo(), Bar(), &fun);
    validator.performValidations();
    
    XMLCursor!ParserType cursor;
    auto myfun = validator.baz;
    myfun(cursor);
    
    assert(count == 4);
}

struct ElementNestingValidator(CursorType)
{
    import std.experimental.xml.interfaces;
    
    alias StringType = CursorType.StringType;
 
    import std.container.array;   
    Array!StringType stack;
    
    alias ErrorHandlerType = void delegate(ref CursorType, ref typeof(stack));
    ErrorHandlerType errorHandler;
    
    void validate(ref CursorType cursor)
    {
        import std.stdio: writeln;
        import std.experimental.xml.faststrings;
        
        if (cursor.getKind() == XMLKind.ELEMENT_START)
            stack.insert(cursor.getName());
        else if (cursor.getKind() == XMLKind.ELEMENT_END && stack.length > 0)
        {
            if (stack.empty || !fastEqual(stack.back, cursor.getName()))
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
            </bbb>
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
