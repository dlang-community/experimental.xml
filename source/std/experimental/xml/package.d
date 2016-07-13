/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module std.experimental.xml;

import std.typecons: Tuple;
import std.experimental.allocator.gc_allocator;

// building blocks for the chains
private mixin template Chain()
{
    static if (is(Alloc == void))
        alias ActualAlloc = shared(GCAllocator);
    else
        alias ActualAlloc = Alloc;

    private InputType input;
    private ActualAlloc* allocator;
    private CtorArgs ctorArgs;
}
private mixin template AllocMethods(string thisTemplate)
{
    auto withAllocator(Alloc)()
    {
        return withAllocator(&Alloc.instance);
    }
    auto withAllocator(Alloc)(ref Alloc alloc)
    {
        return withAllocator(&alloc);
    }
    auto withAllocator(Alloc)(Alloc* alloc)
    {
        mixin("return " ~ thisTemplate ~ "!(InputType, CurrentType, Alloc, CtorArgs, Options)(input, alloc, ctorArgs);\n");
    }
}
private mixin template OptionsMethod(string name, string thisTemplate)
{
    mixin(
    "   auto with" ~ name ~ "Options(Opts...)()\n" ~
    "   {\n" ~
    "       return " ~ thisTemplate ~ "!(InputType, CurrentType, Alloc, CtorArgs, Options, Opts)(input, allocator, ctorArgs);\n" ~
    "   }\n"
    );
}
private mixin template BindingTemplate()
{
    private static template BindType(alias T)
    {
        static if (is(T!(CurrentType, ActualAlloc, Options)))
            alias BindType = T!(CurrentType, ActualAlloc, Options);
        else static if (is(T!(InputType, ActualAlloc, Options)))
            alias BindType = T!(InputType, ActualAlloc, Options);
        else static if (is(ActualAlloc == void))
        {
            static if (is(T!(CurrentType, Options)))
                alias BindType = T!(CurrentType, Options);
            else static if (is(T!(InputType, Options)))
                alias BindType = T!(InputType, Options);
            else static if (is(T!Options))
                alias BindType = T!Options;
            else static if (is(T!CurrentType) && Options.length == 0)
                alias BindType = T!CurrentType;
            else static if (is(T!InputType) && Options.length == 0)
                alias BindType = T!InputType;
            else static if (is(T) && Options.length == 0)
                alias BindType = T;
        }
        else static if (Options.length == 0)
        {
            static if (is(T!(CurrentType, ActualAlloc)))
                alias BindType = T!(CurrentType, ActualAlloc);
            else static if (is(T!(InputType, ActualAlloc)))
                alias BindType = T!(InputType, ActualAlloc);
            else static if (is(T!ActualAlloc))
                alias BindType = T!ActualAlloc;
        }
        else static if (is(T!(ActualAlloc, Options)))
            alias BindType = T!(ActualAlloc, Options);
    }
}
private mixin template ChainPrevious(string name)
{
    mixin(
    "   auto as" ~ name ~ "()\n" ~
    "   {\n" ~
    "       auto res = CurrentType(ctorArgs.expand);\n" ~
    "       res.setSource(input);\n" ~
    "       return res;\n" ~
    "   }\n"
    );
}
private mixin template ChainNext(string name, string nextTemplate)
{
    mixin BindingTemplate;

    mixin(
    "   auto with" ~ name ~ "(alias Type, Args...)(Args args)\n" ~
    "   {\n" ~
    "       static if (!is(Alloc == void))\n" ~
    "       {\n" ~
    "           alias CA = Tuple!(typeof(allocator), Args, CtorArgs.Types);\n" ~
    "           return " ~ nextTemplate ~ "!(InputType, BindType!Type, Alloc, CA)(input, allocator, CA(allocator, args, ctorArgs.expand));\n" ~
    "       }\n" ~
    "       else\n" ~
    "       {\n" ~
    "           alias CA = Tuple!(Args, CtorArgs.Types);\n" ~
    "           return " ~ nextTemplate ~ "!(InputType, BindType!Type, Alloc, CA)(input, allocator, CA(args, ctorArgs.expand));\n" ~
    "       }\n" ~
    "   }\n"
    );
    
    mixin(
    "   auto withDefault" ~ name ~ "()\n" ~
    "   {\n" ~
    "       return with" ~ name ~ "!Default();\n" ~
    "   }\n"
    );
    
    mixin ("alias withDefault" ~ name ~ " this;\n");
}

// the actual chains

auto withInput(InputType)(auto ref InputType input)
{
    return LexerChain!(InputType, void, void, Tuple!())(input, null, Tuple!()());
}

struct LexerChain(InputType, CurrentType, Alloc, CtorArgs, Options...)
{
    import std.experimental.xml.lexers;
    
    static if (is(SliceLexer!InputType))
        private alias Default = SliceLexer;
    else static if (is(BufferedLexer!InputType))
        private alias Default = BufferedLexer;
    else
        private alias Default = RangeLexer;
    
    mixin Chain;
    mixin AllocMethods!"LexerChain";
    mixin OptionsMethod!("Lexer", "LexerChain");
    mixin ChainNext!("Lexer", "ParserChain");
}

struct ParserChain(InputType, CurrentType, Alloc, CtorArgs, Options...)
{
    import std.experimental.xml.parser;
    private alias Default = Parser;
    
    mixin Chain;
    mixin AllocMethods!"ParserChain";
    mixin OptionsMethod!("Parser", "ParserChain");
    mixin ChainNext!("Parser", "CursorChain");
    mixin ChainPrevious!"Lexer";
}

struct CursorChain(InputType, CurrentType, Alloc, CtorArgs, Options...)
{
    import std.experimental.xml.cursor;
    private alias Default = Cursor;
    
    mixin Chain;
    mixin AllocMethods!"CursorChain";
    mixin OptionsMethod!("Cursor", "CursorChain");
    mixin ChainNext!("Cursor", "ValidatingChain");
    mixin ChainPrevious!"Parser";
}

struct ValidatingChain(InputType, CurrentType, Alloc, CtorArgs, Options...)
{
    import std.experimental.xml.validation;
    private alias Default = ValidatingCursor;
    
    mixin Chain;
    mixin AllocMethods!("ValidatingChain");
    mixin ChainPrevious!"Cursor";
}

struct DomChain(InputType, CurrentType, Alloc, CtorArgs, Options...)
{
    mixin ChainPrevious!("Cursor");
    mixin Chain!("Dom", "DomChain");
}

unittest
{
    import std.experimental.xml.interfaces: XMLKind;
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