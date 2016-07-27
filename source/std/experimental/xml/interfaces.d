/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module contains some traits that serve as interfaces
+   for some components of the library.
+/

module std.experimental.xml.interfaces;

import std.range.primitives;
import std.traits;

// LEVEL 1: LEXERS

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

// LEVEL 2: PARSERS

/++
+   Enumeration of XML events/nodes, used by various components.
+/
enum XMLKind
{
    /++ An entire document, starting with an <?xml ?> declaration +/
    DOCUMENT,
    
    /++ A doctype declaration, delimited by `<!DOCTYPE` and `>` +/
    DOCTYPE,
    
    /++ A start tag, delimited by `<` and `>` +/
    ELEMENT_START,
    
    /++ An end tag, delimited by `</` and `>` +/
    ELEMENT_END,
    
    /++ An empty tag, delimited by `<` and `/>` +/
    ELEMENT_EMPTY,
    
    /++ A text element, without any specific delimiter +/
    TEXT,
    
    /++ A CDATA section, delimited by `<![CDATA` and `]]>` +/
    CDATA,
    
    /++ A comment, delimited by `<!--` and `-->` +/
    COMMENT,
    
    /++ A processing instruction, delimited by `<?` and `?>` +/
    PROCESSING_INSTRUCTION,
    
    /++ Any kind of declaration, delimited by `<!` and `>` +/
    DECLARATION,
    /// ditto
    ATTLIST_DECL,
    /// ditto
    ELEMENT_DECL,
    /// ditto
    ENTITY_DECL,
    /// ditto
    NOTATION_DECL,
    
    /++ A conditional section, delimited by `<![` and `]]>` +/
    CONDITIONAL,
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
    XMLKind kind;
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
    enum bool isLowLevelParser = isInputRange!P && is(ElementType!P : XMLToken!(P.CharacterType)) && is(typeof(
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

// LEVEL 3: CURSORS   

template isCursor(CursorType)
{
    enum bool isCursor = is(typeof(
    (inout int = 0)
    {
        /++
        +   The type of input accepted by this parser,
        +   i.e., the one accepted by the underlying low level parser.
        +/
        alias T = CursorType.InputType;
        
        alias S = CursorType.StringType;
        
        CursorType cursor;
        T input;
        bool b;
        
        cursor.setSource(input);
        b = cursor.atBeginning;
        b = cursor.documentEnd;
        b = cursor.next;
        b = cursor.enter;
        cursor.exit;
        XMLKind kind = cursor.getKind;
        auto s = cursor.getName;
        s = cursor.getLocalName;
        s = cursor.getPrefix;
        s = cursor.getContent;
        s = cursor.getAll;
        auto attrs = cursor.getAttributes;
    }
    ));
}

template isSaveableCursor(CursorType)
{
    enum bool isSaveableCursor = isCursor!CursorType && is(typeof(
    (inout int = 0)
    {
        const CursorType cursor1;
        
        /++
        +   L save() const;
        +   Return a copy of the lexer that can be advance independently of the original.
        +/
        CursorType cursor2 = cursor1.save();
    }));
}