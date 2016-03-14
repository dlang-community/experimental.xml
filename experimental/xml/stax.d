
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

struct StAXParser(T)
    if(isLowLevelParser!T)
{
    alias InputType = T.InputType;
    alias CharacterType = T.CharacterType;
    alias StringType = CharacterType[];
    
    private T parser;
    private ElementType!InputType currentNode, nextNode;
    private int status = 0;          // 0: {}, 1: {currentNode}, 2: {currentNode, nextNode}
    private bool hasParsedAttributes;
    private StringType[] attributes; // only if hasParsedAttributes == true
    private StringType[] namespaces; // only if hasParsedAttributes == true
    
    void setSource(InputType input)
    {
        parser.setSource(input);
    }
    
    // ADVANCED API
    // does not process children if you don't use enter()
    // does not process attributes if you don't ask for them
    
    // jumps to the first child of current node
    void enter()
    {
        if(status == 2)
            currentNode = nextNode;
        else
        {
            currentNode = input.front;
            input.popFront;
        }
        status = 1;
    }
    
    // jumps to the end of parent
    void exit();
    
    // jumps to the next sibling of current node (filtering by kind or name)
    void next();
    void next(Kind kind)
    {
        do
            next();
        while(getKind() != kind);
    }
    void next(S name)
    {
        do
            next();
        while(getName() != name);
    }
    
    // whether the current node has children, and enter() can be used
    bool hasChildren() const;
    // whether the current node has a succesive sibling, and next() can be used
    bool hasSibling() const;
    
    Kind getKind() const;
    
    // element name or processing instruction target
    StringType getName() const;
    // element unqualified name
    StringType getLocalName() const;
    // element prefix
    StringType getPrefix() const;
    
    // element attributes or document attributes (version, encoding, ...), as triplets (prefix, name, value)
    Tuple!(StringType, StringType, StringType)[] getAttributes() const;
    Tuple!(StringType, "prefix", StringType, "namespace")[] getNamespaceDefinitions() const;
    
    // comment content or cdata content or text content or processing instruction data or doctype internal DTD
    StringType getText() const;
    
    // RANGE API
    // produces an inputRange of completely processed nodes
    
    struct Node
    {
        StringType localName;
        StringType namePrefix;
        
        Tuple!(StringType, "prefix", StringType, "name", StringType, "value")[] attributes;
        Tuple!(StringType, "prefix", StringType, "namespace")[] namespaceDefinitions;
        
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