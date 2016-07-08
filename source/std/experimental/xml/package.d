/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module std.experimental.xml;

import std.experimental.xml.interfaces;
import std.typecons: Tuple;

auto withInput(InputType)(auto ref InputType input)
{
    return XMLChain1!InputType(input);
}

struct XMLChain1(InputType)
{
    InputType input;
    
    auto withLexer(alias LexerType)()
    {
        static if (is(LexerType) && isLexer!LexerType)
            return XMLChain2!(LexerType, InputType)(input);
        else static if (is(LexerType!InputType) && isLexer!(LexerType!InputType))
            return XMLChain2!(LexerType!InputType, InputType)(input);
        else static assert(0, LexerType.stringof ~ " is not an appropriate lexer for input type " ~ InputType.stringof);
    }
    auto withDefaultLexer()
    {
        import std.experimental.xml.lexers;
        static if (__traits(compiles, SliceLexer!InputType))
        {
            return withLexer!SliceLexer;
        }
        else static if (__traits(compiles, BufferedLexer!InputType))
        {
            return withLexer!BufferedLexer;
        }
        else static if (__traits(compiles, RangeLexer!InputType))
        {
            return withLexer!RangeLexer;
        }
        else static assert(0, "Could not find an appropriate lexer for input type " ~ InputType.stringof);
    }
    alias withDefaultLexer this;
}

struct XMLChain2(LexerType, InputType)
{
    InputType input;
    
    auto withParser(alias ParserType)()
    {
        static if (is(ParserType) && isLowLevelParser!ParserType)
            return XMLChain3!(ParserType, InputType)(input);
        else static if (is(ParserType!LexerType) && isLowLevelParser!(ParserType!LexerType))
            return XMLChain3!(ParserType!LexerType, InputType)(input);
        else static assert(0, ParserType.stringof ~ " is not an appropriate parser for lexer " ~ LexerType.stringof);
    }
    auto withDefaultParser()
    {
        import std.experimental.xml.parser;
        return withParser!Parser;
    }
    auto withParserOptions(Args...)()
    {
        import std.experimental.xml.parser;
        import std.experimental.allocator.gc_allocator;
        return withParser!(Parser!(LexerType, shared(GCAllocator), Args));
    }
    alias withDefaultParser this;
    
    auto asLexer(Args...)(Args args)
    {
        auto result = LexerType(args);
        result.setSource(input);
        return result;
    }
}

struct XMLChain3(ParserType, InputType)
{
    InputType input;
    
    auto withCursor(alias CursorType)()
    {
        static if (is(CursorType) && isCursor!CursorType)
            return XMLChain4!(CursorType, InputType)(input);
        else static if (is(CursorType!ParserType) && isCursor!(CursorType!ParserType))
            return XMLChain4!(CursorType!ParserType, InputType)(input);
        else static assert(0, CursorType.stringof ~ " is not an appropriate cursor for parser " ~ ParserType.stringof);
    }
    auto withDefaultCursor()
    {
        import std.experimental.xml.cursor;
        return withCursor!Cursor;
    }
    auto withCursorOptions(Args...)()
    {
        import std.experimental.xml.cursor;
        return withCursor!(Cursor!(ParserType, Args));
    }
    alias withDefaultCursor this;
    
    auto asParser(Args...)(Args args)
    {
        auto result = ParserType(args);
        result.setSource(input);
        return result;
    }
}

struct XMLChain4(CursorType, InputType, Validations...)
{
    import std.experimental.xml.validation;
    import std.experimental.xml.sax;
    import std.typecons: Tuple;
    
    private template TupleType(Validations...)
    {
        static if (Validations.length == 0)
            alias TupleType = Tuple!Validations;
        else
            alias TupleType = Tuple!(typeof(ValidatingCursor!(CursorType, Validations[0..2])), Validations[2..$]);
    }
    private template SAXParserHandler(alias H)
    {
        alias SAXParserHandler = typeof(SAXParser!(ValidatingCursor!(CursorType, Validations), H).handler);
    }

    InputType input;
    TupleType!Validations valids;

    auto withValidation(string name, alias T)()
    {
        alias ResultType = XMLChain4!(ParserType, LexerType, InputType, T, name, Validations);
        return ResultType(input, typeof(ResultType.valids)(typeof(ResultType.valids[$-1]).init, valids.expand));
    }
    auto withValidation(string name, alias T)(auto ref T valid)
    {
        alias ResultType = XMLChain4!(ParserType, LexerType, InputType, T, name, Validations);
        return ResultType(input, typeof(ResultType.valids)(valid, valids.expand));
    }
    
    auto asCursor(Args...)(Args args)
    {
        auto result = ValidatingCursor!(CursorType, Validations)(valids.expand, args);
        result.setSource(input);
        return result;
    }
    auto asSAXParser(alias H, Args...)(SAXParserHandler!H handler, Args args)
    {
        auto result = SAXParser!(ValidatingCursor!(CursorType, Validations))(valids, args);
        result.setSource(input);
        result.handler = handler;
        return result;
    }
    auto asSAXParser(alias H, Args...)(Args args)
    {
        return asSAXParser!(H, Args)(SAXParserHandler!H(), args);
    }
}

unittest
{
    import std.experimental.xml.parser: ParserOptions;
    import std.experimental.xml.cursor: CursorOptions;
   
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
    
    auto cursor =
         withInput(xml)
        .withParserOptions!(ParserOptions.CopyStrings)
        .withCursorOptions!(CursorOptions.DontConflateCDATA)
        .asCursor;
        
    assert(cursor.getKind == XMLKind.DOCUMENT);
}