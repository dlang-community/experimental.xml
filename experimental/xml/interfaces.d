
/++
+   This module contains some traits that serve as interfaces
+   for some components of the library.
+/

module experimental.xml.interfaces;

/++
+   Checks whether its argument fulfills all requirements to be used as XML lexer.
+
+   An XML lexer is the first component in the parsing chain. It masks from the parser
+   the shape of the input and the type of the characters in it.
+/
template isLexer(L)
{
    enum bool isLexer = is(typeof(
    (inout int = 0)
    {
        /++
        +   The type of a single character from the input.
        +   The parser will deal with slices of this type.
        +/
        alias C = L.CharacterType;
        
        /++ The type of the input source. +/
        alias T = L.InputType;
        
        L lexer;
        T source;
        char c;
        bool b;
        string s;
        C[] cs;
        
        /++
        +   void setSource(InputType);
        +   Sets the input source for this lexer.
        +/
        lexer.setSource(source);
        
        /++
        +   bool empty() const;
        +   Checks whether there are more characters available.
        +/
        b = lexer.empty;
        
        /++
        +   void start();
        +   Sets the start of an input sequence,
        +   that will be returned by a call to get().
        +/
        lexer.start();
        
        /++
        +   CharacterType[] get() const;
        +   Return the sequence of characters starting at the last call
        +   to start() and ending at the actual position in the input.
        +/
        cs = lexer.get();
        
        /++
        +   bool testAndAdvance(char)
        +   Tests whether the current character equals to the given one.
        +   If true, also advances the input to the next character.
        +/
        b = lexer.testAndAdvance(c);
        
        /++
        +   void advanceUntil(char, bool)
        +   Advances the input until it finds the given character.
        +   The boolean argument specifies whether the lexer should also advance past the given character.
        +/
        lexer.advanceUntil(c, b);
        
        /++
        +   void advanceUntilAny(string, bool)
        +   Advances the input until it finds any character from the given string.
        +   The boolean argument specifies whether the lexer should also advance past the character found.
        +/
        lexer.advanceUntilAny(s, b);
        
        /++
        +   void dropWhile(string)
        +   While the current input character is present in the given string, advance.
        +   Characters advanced by this method may not be returned by get().
        +/
        lexer.dropWhile(s);
    }));
}

/++
+   Checks whether the given lexer is savable.
+
+   The method save should return an exact copy of the lexer
+   that can be advanced independently of the original.
+/
template isSaveableLexer(L)
{
    enum bool isSaveableLexer = isLexer!L && is(typeof(
    (inout int = 0)
    {
        const L lexer1;
        
        /++
        +   L save() const;
        +   Return a copy of the lexer that can be advance independently of the original.
        +/
        L lexer2 = lexer1.save();
    }));
}

/++
+   The structure returned in output from the low level parser.
+   Represents an XML token, delimited by specific patterns, based on its kind.
+   This delimiters shall not be omitted from the content field.
+/
struct XMLToken(T)
{
    /++ The content of the token +/
    T[] content;
    
    /++ Represents the kind of token +/
    enum Kind
    {
        /++ A text element, without any specific delimiter +/
        TEXT,
        
        /++ An end tag, delimited by `</` and `>` +/
        END_TAG,
        
        /++ A processing instruction, delimited by `<?` and `?>` +/
        PROCESSING,
        
        /++ A start tag, delimited by `<` and `>` +/
        START_TAG,
        
        /++ An empty tag, delimited by `<` and `/>` +/
        EMPTY_TAG,
        
        /++ A CDATA section, delimited by `<![CDATA` and `]]>` +/
        CDATA,
        
        /++ A conditional section, delimited by `<![` and `]]>` +/
        CONDITIONAL,
        
        /++ A comment, delimited by `<!--` and `-->` +/
        COMMENT,
        
        /++ A doctype declaration, delimited by `<!DOCTYPE` and `>` +/
        DOCTYPE,
        
        /++ Any kind of declaration, delimited by `<!` and `>` +/
        DECLARATION,
    };
    
    /++ ditto +/
    Kind kind;
}

/++
+   Checks whether its argument fulfills all requirements to be used as XML lexer.
+
+   An XML lexer is the first component in the parsing chain. It masks from the parser
+   the shape of the input and the type of the characters in it. It must be an InputRange
+   of some instantiation of LowLevelNode.
+/
template isLowLevelParser(P)
{
    enum bool isLowLevelParser = isInputRange!P && TemplateOf(ElementType!P, XMLToken) && is(typeof(
    (inout int = 0)
    {
        /++
        +   The type of input this parser accepts,
        +   i.e. the type of input the underlying lexer accepts.
        +/
        alias InputType = P.InputType;
        
        /++
        +   The type of a single character from the input.
        +   The parser will deal with slices of this type.
        +/
        alias CharacterType = P.CharacterType;
        
        P parser;
        InputType input;
        
        /++
        +   void setSource(InputType);
        +   Initializes the parser (and the underlying lexer) with the given input.
        +/
        parser.setSource(input);
    }));
}

/++
+   Checks whether the given parser is savable.
+
+   Being an InputRange, the parser is savable if and only if it is also a ForwardRange.
+/
template isSaveableLowLevelParser(P)
{
    enum bool isSaveableLowLevelParser = isLowLevelParser!P && isForwardRange!P;
}

/++
+   Enumeration of XML events/nodes, used by various components.
+/
enum XMLKind
{
    DOCUMENT,
    ELEMENT_START,
    ELEMENT_END,
    ELEMENT_EMPTY,
    TEXT,
    COMMENT,
    PROCESSING_INSTRUCTION,
}