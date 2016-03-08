
/*
*   --- WORK IN PROGRESS ---
*   --- DOES NOT COMPILE ---
*   ---  NOT DOCUMENTED  ---
*/

module experimental.xml.stax;

enum Kind
{
    TAG,
    EMPTY_TAG,
    PROCESSING_INSTRUCTION,
    CDATA,
    TEXT,
}

struct StAXParser(T)
    if(isXmlLowLevelParser!T)
{
    alias InputType = T;
    alias CharacterType = InputType.CharacterType;
    
    private InputType input;
    private ElementType!InputType currentNode, nextNode;
    private int status; // 0: {}, 1: {currentNode}, 2: {currentNode, nextNode}
    
    void setSource(InputType input)
    {
        this.input = input;
    }
    
    // jumps to the next inner-level element
    void enter();
    // jumps to the next outer-level element
    void exit();
    // jumps to the next same-level element (filter by kind)
    void next();
    void next(Kind kind);
    
    Kind getKind() const;
    Tuple!(T[], "namespace", T[], "name") getElement() const;
    (Tuple!(T[], "namespace", T[], "name", T[], "value"))[] getAttributes() const;
    T[] getText() const;
    bool hasMoreChildren() const;
    
    auto empty() const;
    auto front() const;
    auto popFront();
}