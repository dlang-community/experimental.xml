
/++ This module implements a streaming XML parser.+/

module experimental.xml.stax;

enum Kind
{
    TAG,
    EMPTY_TAG,
    PROCESSING_INSTRUCTION,
    CDATA,
    TEXT,
    DOCTYPE,
    DOCUMENT,
    COMMENT,
}

/++
+   Built on top of the low level parser, the streaming parser
+   offers 2 APIs: a simple InputRange that returns every node of the document,
+   and an advanced API that allows to advance a cursor inside the document,
+   to collect infos about the current node and to choose whether to skip its children.
+/
struct StAXParser(T)
    if(isLowLevelParser!T)
{
    /++
    +   The type of input accepted by this parser,
    +   i.e., the one accepted by the underlying low level parser.
    +/
    alias InputType = T.InputType;
    
    /++ The type of characters in the input, as returned by the underlying low level parser. +/
    alias CharacterType = T.CharacterType;
    
    /++ The type of sequences of CharacterType, as returned by this parser +/
    alias StringType = CharacterType[];
    
    private T parser;
    private ElementType!InputType currentNode;
    
    /++
    +   Initializes this parser (and the underlying low level one) with the given input.
    +/
    void setSource(InputType input)
    {
        parser.setSource(input);
    }
    
    //----- START OF ADVANCED API -----//
    
    /++ Selects the first child of the current node as the new current node. +/
    void enter()
    {
        currentNode = input.front;
        input.popFront;
    }
    
    /++ Selects the parent of the current node as the new current node. +/
    void exit()
    {
    
    }
    
    /++ Selects the next sibling of the current node as the new current node. +/
    void next();
    
    /++ Returns whether the current node has children, and enter() can thus be used. +/
    bool hasChildren() const;
    
    /++ Returns whether the current node has a successive sibling, and next() can thus be used. +/
    bool hasSibling() const;
    
    /++ Returns the kind of the current node. +/
    Kind getKind() const;
    
    /++
    +   If the current node is an element, return its complete name;
    +   it it is a processing instruction, return its target;
    +   otherwise, the result is unspecified.
    +/
    StringType getName() const;
    
    /++
    +   If the current node is an element, return its local name (without namespace prefix);
    +   otherwise, return the same result as getName().
    +/
    StringType getLocalName() const;
    
    /++
    +   If the current node is an element, return its namespace prefix;
    +   otherwise, the result in unspecified;
    +/
    StringType getPrefix() const;
    
    /++
    +   If the current node is an element, return its attributes as an array of triplets
    +   (prefix, name, value); if the current node is the document node, return the attributes
    +   of the xml declaration (encoding, version, ...); otherwise, return an empty array.
    +/
    Tuple!(StringType, StringType, StringType)[] getAttributes() const;
    
    /++
    +   If the current node is an element, return a list of namespace bindings created in this element
    +   start tag, as an array of pairs (prefix, namespace); otherwise, return an empty array.
    +/
    Tuple!(StringType, "prefix", StringType, "namespace")[] getNamespaceDefinitions() const;
    
    /++
    +   Return the text content of a CDATA section, a comment, a text node, or the internal DTD
    +   of a doctype declaration; in all other cases, the result in unspecified.
    +/
    StringType getText() const;
    
    //----- START OF SIMPLE, RANGED-BASED API -----//
    
    /++ The type this StAXParser is an InputRange of. +/
    struct Node
    {
        /++ See function StAXParser.getLocalName(). +/
        StringType localName;
        
        /++ See function StAXParser.getPrefix(). +/
        StringType namePrefix;
        
        /++ See function StAXParser.getAttributes(). +/
        Tuple!(StringType, "prefix", StringType, "name", StringType, "value")[] attributes;
        
        /++ See function StAXParser.getNamespaceDefinitions(). +/
        Tuple!(StringType, "prefix", StringType, "namespace")[] namespaceDefinitions;
        
        /++ See function StAXParser.getText(). +/
        StringType text;
    }
    
    bool empty() const
    {
        return parser.empty;
    }
    Node front() const
    {
        Node result;
        result.localName = getLocalName();
        result.namePrefix = getPrefix();
        result.attributes = getAttributes();
        result.namespaceDefinitions = getNamespaceDefinitions();
        result.text = getText();
        return result;
    }
    void popFront()
    {
        if(hasChildren())
            enter();
        else if(hasSibling())
            next();
        else
            exit();
    }
    
    static if(isSavableLowLevelParser!T)
        auto save() const;
}