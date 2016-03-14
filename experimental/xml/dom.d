
module experimental.xml.dom;

struct DOMBuilder(T)
    if(isLowLevelParser!T)
{
    alias InputType = T.InputType;
    alias CharacterType = T.CharacterType;
    alias StringType = CharacterType[];
    
    private T parser;
    void setSource(InputType input)
    {
        parser.setSource(input);
    }
    
    // ADVANCED API
    // only adds to the DOM only when you call build() or buildRecursive()
    
    // jumps to the next inner-level node
    void enter();
    // jumps to the next outer-level node
    void exit();
    // jumps to the next same-level node (with parameter: filter by kind)
    void next();
    void next(Kind kind);
    // adds the current node to the DOM (with parameter: with all its children)
    void build();
    void buildRecursive();
    
    bool hasChildren() const;
    Kind getKind() const;
    
    // element name or processing instruction target or or notation name
    // or name of the element for element declarations and attlist declarations
    StringType getName() const;
    // element unqualified name
    StringType getLocalName() const;
    // element prefix
    StringType getPrefix() const;
    
    // SIMPLE API
    // builds the entire DOM
    
    Document(StringType) buildAll();
}

class XMLObject(S)
{
    XMLObject parent;
}

class Document(S): XMLObject!S
{
    S xmlVersion;
    S encoding;
    
    XMLObject!S[] children;
}

class Element(S): XMLObject!S
{
    S prefix;
    S localName;
    
    Triple!(S, "prefix", S, "localName", S, "value")[] attributes;
    XMLObject!S[] children;
}

class ProcessingInstruction(S): XMLObject!S
{
    S target;
    S data;
}

class Comment(S): XMLObject!S
{
    S text;
}

class CDATASection(S): XMLObject!S
{
    S text;
}

class Text(S): XMLObject!S
{
    S text;
}
