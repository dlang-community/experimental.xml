
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
        char c;
        bool b;
        string s;
        C[] cs;
        
        lexer.setSource(source);            // void setSource(InputType)
        b = lexer.empty;                    // bool empty
        lexer.start();                      // void start();
        cs = lexer.get();                   // CharacterType[] get() const;
        b = lexer.testAndAdvance(c);        // bool testAndEat(char)
        lexer.advanceUntil(c, b);           // void advanceUntil(char, bool)
        lexer.advanceUntilEither(c, c);     // void advanceUntilEither(char, char)
        lexer.advanceUntilAny(c, c, c);     // void advanceUntilAny(char, char, char)
        lexer.dropWhile(s);                 // void drowWhile(string)
    }));
}

template isSaveableLexer(L)
{
    enum bool isSaveableLexer = isLexer!L && is(typeof(
    (inout int = 0)
    {
        const L lexer1;
        
        // Returns an independent copy of the lexer
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
        DOCTYPE,            // <!DOCTYPE [ ] >
        DECLARATION,        // <!  >
    };
    Kind kind;
}

template isLowLevelParser(P)
{
    enum bool isLowLevelParser = isInputRange!P && TemplateOf(ElementType!P, LowLevelNode) && is(typeof(
    (inout int = 0)
    {
        // The type of input handled by the parser; should depend on the underlying lexer
        alias InputType = P.InputType;  // type P.InputType
        
        P parser;
        InputType input;
        
        // Initializes the parser with the input source
        parser.setSource(input);        // void setSource(InputType);
    }));
}

template isSaveableLowLevelParser(P)
{
    enum bool isSaveableLowLevelParser = isLowLevelParser!P && isForwardRange!P;
}