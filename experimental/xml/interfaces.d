
module experimental.xml.interfaces;

/*
*   LEXER INTERFACE
*   The lexer provides methods to read sequences of characters from input
*   It does not have any xml knowledge
*   A specialized lexer should be used for each kind of input source (range, slice, ...)
*/

template isLexer(L)
{
    enum bool isLexer = is(typeof(
    (inout int = 0)
    {
        alias C = L.CharacterType;          // type L.CharacterType
        alias T = L.InputType;              // type L.InputType
        
        L lexer;
        T source;
        dchar c;
        dstring s;
        bool b;
        C[] cs;
        
        lexer.setSource(source);            // void setSource(InputType)
        b = lexer.empty;                    // bool empty
        b = lexer.testAndEat(c);            // bool testAndEat(dchar)
        cs = lexer.readUntil(c, b);         // CharacterType[] readUntil(dchar, bool)
        cs = lexer.readUntil(s, b);         // CharacterType[] readUntil(dstring, bool)
        cs = lexer.readBalanced(s, s, b);   // CharacterType[] readBalanced(dstring, dstring, bool)
        lexer.skip(s);                      // void skip(dstring)
    }));
}

template isSaveableLexer(L)
{
    enum bool isSaveableLexer = isLexer!L && is(typeof(
    (inout int = 0)
    {
        const L lexer1;
        L lexer2 = lexer1.save();           // L save() const;
    }));
}

/*
*   LOW LEVEL PARSER INTERFACE
*   Provides dumb xml tokenization; the finest parsing is left to a higher level API
*   Should not be specialized: the implementation shipped in lexer.d should be fine for all usages
*   May also work for not-exactly-xml formats
*/

struct LowLevelNode(T)
{
    T[] content;
    enum Kind
    {
        TEXT,               //
        END_TAG,            // </  >
        PROCESSING,         // <? ?>
        START_TAG,          // <   >
        EMPTY_TAG,          // <  />
        CDATA,              // <![CDATA[   ]]>
        CONDITIONAL,        // <![     [   ]]>
        COMMENT,            // <!--        -->
        DECLARATION,        // <!  >
    };
    Kind kind;
}

template isLowLevelParser(P)
{
    enum bool isLowLevelParser = isInputRange!P && TemplateOf(ElementType!P, LowLevelNode) && is(typeof(
    (inout int = 0)
    {
        alias InputType = P.InputType;  // type P.InputType
        
        P parser;
        InputType input;
        
        parser.setSource(input);        // void setSource(InputType);
    }));
}

template isSaveableLowLevelParser(P)
{
    enum bool isSaveableLowLevelParser = isLowLevelParser!P && isForwardRange!P;
}