
module std.experimental.xml.cursor;

import std.experimental.xml.interfaces;
import std.experimental.xml.faststrings;

import std.range.primitives;
import std.typecons;

struct XMLCursor(P)
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
    
    private P parser;
    private ElementType!P currentNode;
    private bool starting;
    private Attribute!StringType[] attributes;
    private NamespaceDeclaration!StringType[] namespaces;
    private bool attributesParsed;
    private ErrorHandler handler;
    
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
        if (!documentEnd)
        {
            advanceInput();
            if (currentNode.kind == currentNode.kind.PROCESSING && fastEqual(currentNode.content[0..3], "xml"))
                starting = true;
            else
            {
                // document without xml declaration???
                callHandler(this, Error.MISSING_XML_DECLARATION);
                starting = false;
            }
        }
    }
    
    /++ Returns whether the cursor is at the end of the document. +/
    bool documentEnd()
    {
        return parser.empty();
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
        while (next()) {}
        if (!documentEnd)
            advanceInput();
    }
    
    /++
    +   Advances to the next sibling of the current node.
    +   Returns whether it succeded. If it fails, either the
    +   document has ended or the only meaningful operation is exit().
    +/
    bool next()
    {
        if (documentEnd || starting)
            return false;
        else if (currentNode.kind != currentNode.kind.START_TAG)
        {
            if (parser.front.kind == currentNode.kind.END_TAG)
                return false;
            advanceInput();
        }
        else
        {
            int count = 1;
            while (count > 0)
            {
                advanceInput();
                if (currentNode.kind == currentNode.kind.START_TAG)
                    count++;
                else if (currentNode.kind == currentNode.kind.END_TAG)
                    count--;
            }
            if (documentEnd)
                return false;
            if (parser.front.kind == currentNode.kind.END_TAG)
                return false;
            advanceInput();
        }
        return true;
    }
    
    /++ Returns whether the current node has children, and enter() can thus be used. +/
    bool hasChildren()
    {
        return starting ||
              (currentNode.kind == currentNode.kind.START_TAG && parser.front.kind != currentNode.kind.END_TAG);
    }
    
    /++ Returns the kind of the current node. +/
    XMLKind getKind() const
    {
        XMLKind result;
        if (starting)
            return XMLKind.DOCUMENT;
        else switch(currentNode.kind)
        {
            case currentNode.kind.DOCTYPE:
                result = XMLKind.DOCTYPE;
                break;
            case currentNode.kind.START_TAG:
                result = XMLKind.ELEMENT_START;
                break;
            case currentNode.kind.END_TAG:
                result = XMLKind.ELEMENT_END;
                break;
            case currentNode.kind.EMPTY_TAG:
                result = XMLKind.ELEMENT_EMPTY;
                break;
            case currentNode.kind.TEXT:
            case currentNode.kind.CDATA:
                result = XMLKind.TEXT;
                break;
            case currentNode.kind.COMMENT:
                result = XMLKind.COMMENT;
                break;
            case currentNode.kind.PROCESSING:
                result = XMLKind.PROCESSING_INSTRUCTION;
                break;
            default:
                break;
        }
        return result;
    }
    
    /++
    +   If the current node is an element or a doctype, return its complete name;
    +   it it is a processing instruction, return its target;
    +   otherwise, return an empty string;
    +/
    StringType getName() const
    {
        ptrdiff_t i;
        if (currentNode.kind != currentNode.kind.TEXT && 
            currentNode.kind != currentNode.kind.COMMENT &&
            currentNode.kind != currentNode.kind.CDATA)
        {
            auto nameStart = fastIndexOfNeither(currentNode.content, " \r\n\t");
            if ((i = fastIndexOfAny(currentNode.content[nameStart..$], " \r\n\t")) >= 0)
                return currentNode.content[nameStart..i];
            else
                return currentNode.content[nameStart..$];
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
        if (currentNode.kind == currentNode.kind.START_TAG || currentNode.kind == currentNode.kind.END_TAG)
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
            return currentNode.content[0..colon];
        else
            return [];
    }
    
    private void parseAttributeList()
    {
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
                namespaces ~= NamespaceDeclaration!StringType(name, value);
            else
                attributes ~= Attribute!StringType(prefix, name, value);
            
            attStart = attEnd + 1;
            delta = fastIndexOfNeither(currentNode.content[attStart..$], " \r\t\n>");
        }
    }
    
    /++
    +   If the current node is an element, return its attributes as an array of triplets
    +   (prefix, name, value); if the current node is the document node, return the attributes
    +   of the xml declaration (encoding, version, ...); otherwise, return an empty array.
    +/
    auto getAttributes()
    {
        auto kind = currentNode.kind;
        if (kind == kind.START_TAG || kind == kind.PROCESSING)
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
        if (kind == kind.START_TAG)
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
            case currentNode.kind.TEXT:
            case currentNode.kind.CDATA:
            case currentNode.kind.COMMENT:
                return currentNode.content;
            case currentNode.kind.DOCTYPE:
            case currentNode.kind.PROCESSING:
            {
                auto nameStart = fastIndexOfNeither(currentNode.content, " \r\n\t");
                if (nameStart < 0)
                    assert(0);
                auto nameEnd = fastIndexOfAny(currentNode.content[nameStart..$], " \r\n\t");
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

unittest
{
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.string: splitLines;
    
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
    
    auto cursor = XMLCursor!(Parser!(SliceLexer!string))();
    cursor.setSource(xml);
    
    // <?xml encoding = "utf-8" ?>
    assert(cursor.getKind() == XMLKind.DOCUMENT);
    assert(cursor.getName() == "xml");
    assert(cursor.getPrefix() == "");
    assert(cursor.getLocalName() == "xml");
    assert(cursor.getAttributes() == [Attribute!string("", "encoding", "utf-8")]);
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
        assert(cursor.getNamespaceDefinitions() == [NamespaceDeclaration!string("myns", "something")]);
        assert(cursor.getText() == []);
        assert(cursor.hasChildren());
        
        cursor.enter();
            // <myns:bbb myns:att='>'>
            assert(cursor.getKind() == XMLKind.ELEMENT_START);
            assert(cursor.getName() == "myns:bbb");
            assert(cursor.getPrefix() == "myns");
            assert(cursor.getLocalName() == "bbb");
            assert(cursor.getAttributes() == [Attribute!string("myns", "att", ">")]);
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
                // use splitlines so the unittest does not depend on the newline policy of this file
                assert(cursor.getText().splitLines == ["Lots of Text!", "            On multiple lines!", "        "]);
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
