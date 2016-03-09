
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
        // The kind of character handled by the lexer; should be comparable with dchar
        alias C = L.CharacterType;          // type L.CharacterType
        // The kind of input taken by the lexer
        alias T = L.InputType;              // type L.InputType
        
        L lexer;
        T source;
        dchar c;
        dstring s;
        bool b;
        C[] cs;
        
        // Initializes the lexer with the input source
        lexer.setSource(source);            // void setSource(InputType)
        // Checks if there are more characters to parse
        b = lexer.empty;                    // bool empty
        // Checks if the character at the current position compares equal to c;
        // if yes, also advances to next character
        b = lexer.testAndEat(c);            // bool testAndEat(dchar)
        // Reads from the source until it finds character c; if the first boolean is true, also
        // consumes c; if the second boolean is true, the returned slice includes c
        cs = lexer.readUntil(c, b, b);      // CharacterType[] readUntil(dchar, bool, bool)
        // Reads from the source until it finds sequence s; if b is true, the returned slice includes
        // that sequence; the sequence is always consumed from input, even if not returned
        cs = lexer.readUntil(s, b);         // CharacterType[] readUntil(dstring, bool)
        // Reads from the source until it finds the second sequence, including balanced occurrences of
        // the first and the second sequence; if b is true, the terminating sequence is included in the
        // return slice; the terminating sequence is always consumed from input, even if not returned
        cs = lexer.readBalanced(s, s, b);   // CharacterType[] readBalanced(dstring, dstring, bool)
        // Advances the input until the current character is not in sequence s;
        lexer.skip(s);                      // void skip(dstring)
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