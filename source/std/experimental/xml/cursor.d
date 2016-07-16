/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module std.experimental.xml.cursor;

import std.experimental.xml.interfaces;
import std.experimental.xml.faststrings;

import std.meta: staticIndexOf;
import std.range.primitives;
import std.typecons;
import std.experimental.allocator.gc_allocator;

enum CursorOptions
{
    DontConflateCDATA,
    CopyStrings,
    InternStrings,
    NoGC,
}

struct Cursor(P, Alloc = shared(GCAllocator), options...)
    if (isLowLevelParser!P)
{
    /++
    +   The type of input accepted by this parser,
    +   i.e., the one accepted by the underlying low level parser.
    +/
    alias InputType = P.InputType;
    
    /++ The type of characters in the input, as returned by the underlying low level parser. +/
    alias CharacterType = P.CharacterType;
    
    /++ The type of sequences of CharacterType, as returned by this parser +/
    alias StringType = CharacterType[];
    
    /++ The type of the error handler that can be installed on this cursor +/
    static if (staticIndexOf!(options, CursorOptions.NoGC) >= 0)
        alias ErrorHandler = void delegate(ref typeof(this), Error) @nogc;
    else
        alias ErrorHandler = void delegate(ref typeof(this), Error);
    
    /++
    + Enumeration of non-fatal errors that applications can intercept by setting
    + an handler on this cursor.
    +/
    enum Error
    {
        MISSING_XML_DECLARATION,
        INVALID_ATTRIBUTE_SYNTAX,
    }
    
    private enum hasInterning = staticIndexOf!(options, CursorOptions.InternStrings) >= 0;
    private enum hasCopying = staticIndexOf!(options, CursorOptions.CopyStrings) >= 0;
    
    private P parser;
    private ElementType!P currentNode;
    private bool starting, _documentEnd;
    private Attribute!StringType[] attributes;
    private NamespaceDeclaration!StringType[] namespaces;
    private bool attributesParsed;
    private ErrorHandler handler;
    
    static if (is(typeof(Alloc.instance)))
        private Alloc* allocator = &(Alloc.instance);
    else
        private Alloc* allocator;
    
    static if (hasInterning)
    {
        import std.experimental.interner;
        static if (hasCopying)
        {
            enum canDeallocate = true;
            Interner!(StringType, OnIntern.Duplicate, Alloc) interner;
        }
        else
        {
            bool canDeallocate = true;
            Interner!(StringType, OnIntern.NoAction, Alloc) interner;
        }
    }
    else bool canDeallocate = false;
    
    private static StringType returnStringType(StringType result)
    {
        static if (hasInterning)
        {
            auto interned = interner.intern(result);
            static if (!hasCopying)
                if (interned is result)
                    canDeallocate = false;
        }
        else static if (hasCopying)
        {
            auto len = val.length * typeof(val[0]).sizeof;
            auto copy = allocator.allocate(len);
            memcpy(copy.ptr, val.ptr, len);
            return cast(StringType)copy;
        }
        else
            return result;
    }
    
    /++ Generic constructor; forwards its arguments to the parser constructor +/
    this(Args...)(Args args)
        if (!is(Args[0] == Alloc*) && !is(Args[0] == Alloc))
    {
        parser = P(args);
        static if (hasInterning)
            interner = typeof(Interner)(allocator);
    }
    /// ditto
    this(Args...)(Alloc* alloc, Args args)
    {
        allocator = alloc;
        this(args);
    }
    /// ditto
    this(Args...)(ref Alloc alloc, Args args)
    {
        allocator = &alloc;
        this(args);
    }
    
    static if (isSaveableLowLevelParser!P)
    {
        public auto save()
        {
            auto result = this;
            result.parser = parser.save;
            return result;
        }
    }
    
    private void callHandler(ref typeof(this) cur, Error err)
    {
        if (handler != null)
            handler(cur, err);
        else
            assert(0);
    }
    
    private void advanceInput()
    {
        currentNode = parser.front;
        parser.popFront();
        attributesParsed = false;
        attributes = [];
        namespaces = [];
        if (canDeallocate)
            parser.deallocateLast;
    }
    
    /++
    +   Overrides the current error handler with a new one.
    +   It will be called whenever a non-fatal error occurs.
    +   The default handler abort parsing by throwing an exception.
    +/
    void setErrorHandler(ErrorHandler handler)
    {
        this.handler = handler;
    }
    
    /++
    +   Initializes this parser (and the underlying low level one) with the given input.
    +/
    void setSource(InputType input)
    {
        parser.setSource(input);
        if (!parser.empty)
        {
            if (parser.front.kind == XMLKind.PROCESSING_INSTRUCTION && fastEqual(parser.front.content[0..3], "xml"))
                advanceInput();
            else
            {
                // document without xml declaration???
                callHandler(this, Error.MISSING_XML_DECLARATION);
                currentNode.kind = XMLKind.PROCESSING_INSTRUCTION;
                currentNode.content = "xml version = \"1.0\"";
            }
            starting = true;
        }
    }
    
    /++ Returns whether the cursor is at the end of the document. +/
    bool documentEnd()
    {
        return _documentEnd;
    }
    
    /++ Advances to the first child of the current node. +/
    void enter()
    {
        if (starting)
        {
            starting = false;
            advanceInput();
        }
        else if (hasChildren())
            advanceInput();
    }
    
    /++ Advances to the end of the parent of the current node. +/
    void exit()
    {
        if (next())
        {
            static if (!hasInterning)
                canDeallocate = true;
            while (next()) {}
        }
        if (!parser.empty)
            advanceInput();
        else
            _documentEnd = true;
            
        static if (!hasInterning)
            canDeallocate = false;
    }
    
    /++
    +   Advances to the next sibling of the current node.
    +   Returns whether it succeded. If it fails, either the
    +   document has ended or the only meaningful operations are enter() or exit().
    +/
    bool next()
    {
        if (parser.empty || starting)
            return false;
        else if (currentNode.kind != XMLKind.ELEMENT_START)
        {
            if (parser.front.kind == XMLKind.ELEMENT_END)
                return false;
            advanceInput();
        }
        else
        {
            int count = 1;
            while (count > 0)
            {
                advanceInput();
                static if (!hasInterning)
                    canDeallocate = true;
                if (currentNode.kind == XMLKind.ELEMENT_START)
                    count++;
                else if (currentNode.kind == XMLKind.ELEMENT_END)
                    count--;
            }
            static if (!hasInterning)
                canDeallocate = false;
            if (parser.empty)
                return false;
            if (parser.front.kind == XMLKind.ELEMENT_END)
                return false;
            advanceInput();
        }
        return true;
    }
    
    /++ Returns whether the current node has children, and enter() can thus be used. +/
    bool hasChildren()
    {
        return starting ||
              (currentNode.kind == XMLKind.ELEMENT_START && !parser.empty && parser.front.kind != XMLKind.ELEMENT_END);
    }
    
    /++ Returns the kind of the current node. +/
    XMLKind getKind() const
    {
        if (starting)
            return XMLKind.DOCUMENT;
            
        static if (staticIndexOf!(options, CursorOptions.DontConflateCDATA) < 0)
            if (currentNode.kind == XMLKind.CDATA)
                return XMLKind.TEXT;
                
        return currentNode.kind;
    }
    
    /++
    +   If the current node is an element or a doctype, return its complete name;
    +   it it is a processing instruction, return its target;
    +   otherwise, return an empty string;
    +/
    StringType getName() const
    {
        ptrdiff_t i;
        if (currentNode.kind != XMLKind.TEXT && 
            currentNode.kind != XMLKind.COMMENT &&
            currentNode.kind != XMLKind.CDATA)
        {
            auto nameStart = fastIndexOfNeither(currentNode.content, " \r\n\t");
            if (nameStart < 0)
                return [];
                
            StringType result;
            if ((i = fastIndexOfAny(currentNode.content[nameStart..$], " \r\n\t")) >= 0)
                return returnStringType(currentNode.content[nameStart..i]);
            else
                return returnStringType(currentNode.content[nameStart..$]);
        }
        return [];
    }
    
    /++
    +   If the current node is an element, return its local name (without namespace prefix);
    +   otherwise, return the same result as getName().
    +/
    StringType getLocalName() const
    {
        auto name = getName();
        if (currentNode.kind == XMLKind.ELEMENT_START || currentNode.kind == XMLKind.ELEMENT_END)
        {
            auto colon = fastIndexOf(name, ':');
            if (colon != -1)
                return name[(colon+1)..$];
            else
                return name;
        }
        return name;
    }
    
    /++
    +   If the current node is an element, return its namespace prefix;
    +   otherwise, the result in unspecified;
    +/
    StringType getPrefix() const
    {
        auto colon = fastIndexOf(getName(), ':');
        if (colon != -1)
            return returnStringType(currentNode.content[0..colon]);
        else
            return [];
    }
    
    private void parseAttributeList()
    {
        import std.experimental.appender: Appender;
        auto attributesApp = Appender!(Attribute!StringType, Alloc)(allocator);
        auto namespacesApp = Appender!(NamespaceDeclaration!StringType, Alloc)(allocator);
    
        attributesParsed = true;
        auto nameEnd = fastIndexOfAny(currentNode.content, " \r\n\t");
        if (nameEnd < 0)
            return;
        auto attStart = nameEnd;
        auto delta = fastIndexOfNeither(currentNode.content[nameEnd..$], " \r\n\t>");
        while (delta != -1)
        {
            CharacterType[] prefix, name, value;
            attStart += delta;
            
            delta = fastIndexOfAny(currentNode.content[attStart..$], ":=");
            if (delta == -1)
            {
                // attribute without value nor prefix???
                callHandler(this, Error.INVALID_ATTRIBUTE_SYNTAX);
            }
            auto sep = attStart + delta;
            if (currentNode.content[sep] == ':')
            {
                prefix = currentNode.content[attStart..sep];
                attStart = sep + 1;
                delta = fastIndexOf(currentNode.content[attStart..$], '=');
                if (delta == -1)
                {
                    // attribute without value???
                    callHandler(this, Error.INVALID_ATTRIBUTE_SYNTAX);
                    return;
                }
                sep = attStart + delta;
            }
            
            name = currentNode.content[attStart..sep];
            delta = fastIndexOfAny(name, " \r\n\t");
            if (delta >= 0)
                name = name[0..delta];
            
            size_t attEnd;
            size_t quote;
            delta = (sep + 1 < currentNode.content.length) ? fastIndexOfNeither(currentNode.content[sep + 1..$], " \r\n\t") : -1;
            if (delta >= 0)
            {
                quote = sep + 1 + delta;
                if (currentNode.content[quote] == '"' || currentNode.content[quote] == '\'')
                {
                    delta = fastIndexOf(currentNode.content[(quote + 1)..$], currentNode.content[quote]);
                    if (delta == -1)
                    {
                        // attribute quotes never closed???
                        callHandler(this, Error.INVALID_ATTRIBUTE_SYNTAX);
                        return;
                    }
                    attEnd = quote + 1 + delta;
                }
                else
                {
                    callHandler(this, Error.INVALID_ATTRIBUTE_SYNTAX);
                    return;
                }
            }
            else
            {
                // attribute without value???
                callHandler(this, Error.INVALID_ATTRIBUTE_SYNTAX);
                return;
            }
            value = currentNode.content[(quote + 1)..attEnd];
            
            if (prefix.length == 5 && fastEqual(prefix, "xmlns"))
                namespacesApp.put(NamespaceDeclaration!StringType(returnStringType(name), returnStringType(value)));
            else
                attributesApp.put(Attribute!StringType(returnStringType(prefix), returnStringType(name), returnStringType(value)));
            
            attStart = attEnd + 1;
            delta = fastIndexOfNeither(currentNode.content[attStart..$], " \r\t\n>");
        }
        attributes = attributesApp.data;
        namespaces = namespacesApp.data;
    }
    
    /++
    +   If the current node is an element, return its attributes as an array of triplets
    +   (prefix, name, value); if the current node is the document node, return the attributes
    +   of the xml declaration (encoding, version, ...); otherwise, return an empty array.
    +/
    auto getAttributes()
    {
        auto kind = currentNode.kind;
        if (kind == XMLKind.ELEMENT_START || kind == XMLKind.PROCESSING_INSTRUCTION)
        {
            if (!attributesParsed)
                parseAttributeList();
        }
        else
            namespaces = [];
        return attributes;
    }
    
    /++
    +   If the current node is an element, return a list of namespace bindings created in this element
    +   start tag, as an array of pairs (prefix, namespace); otherwise, return an empty array.
    +/
    auto getNamespaceDefinitions()
    {
        auto kind = currentNode.kind;
        if (kind == XMLKind.ELEMENT_START)
        {
            if (!attributesParsed)
                parseAttributeList();
        }
        else
            namespaces = [];
        return namespaces;
    }
    
    /++
    +   Return the text content of a CDATA section, a comment or a text node;
    +   the content of a processing instruction or a doctype;
    +   returns an empty string in all other cases.
    +/
    StringType getText() const
    {
        switch (currentNode.kind)
        {
            case XMLKind.TEXT:
            case XMLKind.CDATA:
            case XMLKind.COMMENT:
                return currentNode.content;
            case XMLKind.DOCTYPE:
            case XMLKind.PROCESSING_INSTRUCTION:
            {
                auto nameStart = fastIndexOfNeither(currentNode.content, " \r\n\t");
                if (nameStart < 0)
                    assert(0);
                auto nameEnd = fastIndexOfAny(currentNode.content[nameStart..$], " \r\n\t");
                nameEnd = nameEnd < 0 ? currentNode.content.length : nameEnd;
                // xml declaration does not have any content
                if(fastEqual(currentNode.content[nameStart..nameEnd], "xml"))
                    return [];
                return currentNode.content[nameEnd..$];
            }
            default:
                return [];
        }
    }
    
    /++ Returns the entire text of the current node. +/
    StringType getAll() const
    {
        return currentNode.content;
    }
}

auto asCursor(T)(auto ref T input)
    if(isLowLevelParser!(T.Type))
{
    struct Chain
    {
        alias Type = Cursor!(T.Type);
        auto finalize()
        {
            return Type(input.finalize(), typeof(Type.currentNode)(), false, [], [], false, null);
        }
    }
    return Chain();
}

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.string: lineSplitter, strip;
    import std.algorithm: map;
    import std.array: array;
    
    wstring xml = q{
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
    
    auto cursor = Cursor!(Parser!(SliceLexer!wstring))();
    cursor.setSource(xml);
    
    // <?xml encoding = "utf-8" ?>
    assert(cursor.getKind() == XMLKind.DOCUMENT);
    assert(cursor.getName() == "xml");
    assert(cursor.getPrefix() == "");
    assert(cursor.getLocalName() == "xml");
    assert(cursor.getAttributes() == [Attribute!wstring("", "encoding", "utf-8")]);
    assert(cursor.getNamespaceDefinitions() == []);
    assert(cursor.getText() == []);
    assert(cursor.hasChildren());
    
    cursor.enter();
        // <aaa xmlns:myns="something">
        assert(cursor.getKind() == XMLKind.ELEMENT_START);
        assert(cursor.getName() == "aaa");
        assert(cursor.getPrefix() == "");
        assert(cursor.getLocalName() == "aaa");
        assert(cursor.getAttributes() == []);
        assert(cursor.getNamespaceDefinitions() == [NamespaceDeclaration!wstring("myns", "something")]);
        assert(cursor.getText() == []);
        assert(cursor.hasChildren());
        
        cursor.enter();
            // <myns:bbb myns:att='>'>
            assert(cursor.getKind() == XMLKind.ELEMENT_START);
            assert(cursor.getName() == "myns:bbb");
            assert(cursor.getPrefix() == "myns");
            assert(cursor.getLocalName() == "bbb");
            assert(cursor.getAttributes() == [Attribute!wstring("myns", "att", ">")]);
            assert(cursor.getNamespaceDefinitions() == []);
            assert(cursor.getText() == []);
            assert(cursor.hasChildren());
            
            cursor.enter();
                // <!-- lol -->
                assert(cursor.getKind() == XMLKind.COMMENT);
                assert(cursor.getName() == "");
                assert(cursor.getPrefix() == "");
                assert(cursor.getLocalName() == "");
                assert(cursor.getAttributes() == []);
                assert(cursor.getNamespaceDefinitions() == []);
                assert(cursor.getText() == " lol ");
                assert(!cursor.hasChildren());
                
                assert(cursor.next());
                // Lots of Text!
                // On multiple lines!
                assert(cursor.getKind() == XMLKind.TEXT);
                assert(cursor.getName() == "");
                assert(cursor.getPrefix() == "");
                assert(cursor.getLocalName() == "");
                assert(cursor.getAttributes() == []);
                assert(cursor.getNamespaceDefinitions() == []);
                // split and strip so the unittest does not depend on the newline policy or indentation of this file
                assert(cursor.getText().lineSplitter.map!"a.strip".array == ["Lots of Text!"w, "On multiple lines!"w, ""w]);
                assert(!cursor.hasChildren());
                
                assert(!cursor.next());
            cursor.exit();
            
            // </myns:bbb>
            assert(cursor.getKind() == XMLKind.ELEMENT_END);
            assert(cursor.getName() == "myns:bbb");
            assert(cursor.getPrefix() == "myns");
            assert(cursor.getLocalName() == "bbb");
            assert(cursor.getAttributes() == []);
            assert(cursor.getNamespaceDefinitions() == []);
            assert(cursor.getText() == []);
            assert(!cursor.hasChildren());
            
            assert(cursor.next());
            // <<![CDATA[ Ciaone! ]]>
            assert(cursor.getKind() == XMLKind.TEXT);
            assert(cursor.getName() == "");
            assert(cursor.getPrefix() == "");
            assert(cursor.getLocalName() == "");
            assert(cursor.getAttributes() == []);
            assert(cursor.getNamespaceDefinitions() == []);
            assert(cursor.getText() == " Ciaone! ");
            assert(!cursor.hasChildren());
            
            assert(cursor.next());
            // <ccc/>
            assert(cursor.getKind() == XMLKind.ELEMENT_EMPTY);
            assert(cursor.getName() == "ccc");
            assert(cursor.getPrefix() == "");
            assert(cursor.getLocalName() == "ccc");
            assert(cursor.getAttributes() == []);
            assert(cursor.getNamespaceDefinitions() == []);
            assert(cursor.getText() == []);
            assert(!cursor.hasChildren());
            
            assert(!cursor.next());
        cursor.exit();
        
        // </aaa>
        assert(cursor.getKind() == XMLKind.ELEMENT_END);
        assert(cursor.getName() == "aaa");
        assert(cursor.getPrefix() == "");
        assert(cursor.getLocalName() == "aaa");
        assert(cursor.getAttributes() == []);
        assert(cursor.getNamespaceDefinitions() == []);
        assert(cursor.getText() == []);
        assert(!cursor.hasChildren());
        
        assert(!cursor.next());
    cursor.exit();
    
    assert(cursor.documentEnd());
}

auto children(T)(ref T cursor)
    if (isCursor!T)
{
    struct XMLRange
    {
        T* cursor;
        bool endReached;
        
        bool empty() const { return endReached; }
        void popFront() { endReached = !cursor.next(); }
        ref T front() { return *cursor; }
        
        ~this() { cursor.exit; }
    }
    if (cursor.hasChildren)
        cursor.enter;
    return XMLRange(&cursor, !cursor.hasChildren);
}

@nogc unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.string: lineSplitter, strip;
    import std.algorithm: map, equal;
    import std.array: array;
    
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
    
    import std.experimental.allocator.mallocator;
    auto alloc = Mallocator.instance;
    
    alias CursorType = Cursor!(Parser!(SliceLexer!string, typeof(alloc)), typeof(alloc), CursorOptions.NoGC, CursorOptions.InternStrings);
    auto cursor = CursorType(alloc, alloc);
    cursor.setSource(xml);
    
    // <?xml encoding = "utf-8" ?>
    assert(cursor.getKind() == XMLKind.DOCUMENT);
    assert(cursor.getName() == "xml");
    assert(cursor.getPrefix() == "");
    assert(cursor.getLocalName() == "xml");
    assert(cursor.getAttributes().length == 1);
    assert(cursor.getAttributes()[0] == Attribute!string("", "encoding", "utf-8"));
    assert(cursor.getNamespaceDefinitions() == []);
    assert(cursor.getText() == []);
    assert(cursor.hasChildren());
    
    {
        auto range1 = cursor.children;
        // <aaa xmlns:myns="something">
        assert(range1.front.getKind() == XMLKind.ELEMENT_START);
        assert(range1.front.getName() == "aaa");
        assert(range1.front.getPrefix() == "");
        assert(range1.front.getLocalName() == "aaa");
        assert(range1.front.getAttributes() == []);
        assert(range1.front.getNamespaceDefinitions().length == 1);
        assert(range1.front.getNamespaceDefinitions()[0] == NamespaceDeclaration!string("myns", "something"));
        assert(range1.front.getText() == []);
        assert(range1.front.hasChildren());
        
        {
            auto range2 = range1.front.children();
            // <myns:bbb myns:att='>'>
            assert(range2.front.getKind() == XMLKind.ELEMENT_START);
            assert(range2.front.getName() == "myns:bbb");
            assert(range2.front.getPrefix() == "myns");
            assert(range2.front.getLocalName() == "bbb");
            assert(range2.front.getAttributes().length == 1);
            assert(range2.front.getAttributes()[0] == Attribute!string("myns", "att", ">"));
            assert(range2.front.getNamespaceDefinitions() == []);
            assert(range2.front.getText() == []);
            assert(range2.front.hasChildren());
            
            {
                auto range3 = range2.front.children();
                // <!-- lol -->
                assert(range3.front.getKind() == XMLKind.COMMENT);
                assert(range3.front.getName() == "");
                assert(range3.front.getPrefix() == "");
                assert(range3.front.getLocalName() == "");
                assert(range3.front.getAttributes() == []);
                assert(range3.front.getNamespaceDefinitions() == []);
                assert(range3.front.getText() == " lol ");
                assert(!range3.front.hasChildren());
                
                range3.popFront;
                assert(!range3.empty);
                // Lots of Text!
                // On multiple lines!
                assert(range3.front.getKind() == XMLKind.TEXT);
                assert(range3.front.getName() == "");
                assert(range3.front.getPrefix() == "");
                assert(range3.front.getLocalName() == "");
                assert(range3.front.getAttributes() == []);
                assert(range3.front.getNamespaceDefinitions() == []);
                // split and strip so the unittest does not depend on the newline policy or indentation of this file
                static immutable linesArr = ["Lots of Text!", "            On multiple lines!", "        "];
                assert(range3.front.getText().lineSplitter.equal(linesArr));
                assert(!range3.front.hasChildren());
                
                range3.popFront;
                assert(range3.empty);
            }
            
            range2.popFront;
            assert(!range2.empty);
            // <<![CDATA[ Ciaone! ]]>
            assert(range2.front.getKind() == XMLKind.TEXT);
            assert(range2.front.getName() == "");
            assert(range2.front.getPrefix() == "");
            assert(range2.front.getLocalName() == "");
            assert(range2.front.getAttributes() == []);
            assert(range2.front.getNamespaceDefinitions() == []);
            assert(range2.front.getText() == " Ciaone! ");
            assert(!range2.front.hasChildren());
            
            range2.popFront;
            assert(!range2.empty());
            // <ccc/>
            assert(range2.front.getKind() == XMLKind.ELEMENT_EMPTY);
            assert(range2.front.getName() == "ccc");
            assert(range2.front.getPrefix() == "");
            assert(range2.front.getLocalName() == "ccc");
            assert(range2.front.getAttributes() == []);
            assert(range2.front.getNamespaceDefinitions() == []);
            assert(range2.front.getText() == []);
            assert(!range2.front.hasChildren());
            
            range2.popFront;
            assert(range2.empty());
        }
        
        range1.popFront;
        assert(range1.empty);
    }
    
    assert(cursor.documentEnd());
}
