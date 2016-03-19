
module experimental.xml.cursor;

import experimental.xml.interfaces;

struct XMLCursor(P)
    if(isLowLevelParser!P)
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
    
    /++ Advances to the first child of the current node. +/
    void enter();
    
    /++ Advances to the end of the parent of the current node. +/
    void exit();
    
    /++
    +   Advances to the next sibling of the current node. Returns whether
    +   it succeded,
    +/
    bool next();
    
    /++ Returns whether the current node has children, and enter() can thus be used. +/
    bool hasChildren() const;
    
    /++ Returns the kind of the current node. +/
    XMLKind getKind() const;
    
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
}