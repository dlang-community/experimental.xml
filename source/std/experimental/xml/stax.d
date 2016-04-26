
/++ This module implements a streaming XML parser.+/

module experimental.xml.stax;

import experimental.xml.interfaces;
import experimental.xml.cursor;

/++
+   Built on top of XMLCursor, the streaming parser adds to it the ability to 
+   be used as an InputRange of XML events starting from the current cursor position.
+   One can freely interleave the use of this component as Cursor and as an InputRange.
+/
struct StAXParser(T)
    if (isLowLevelParser!T)
{
    /++
    +   The underlying XMLCursor methods are exposed, so that one can, for example,
    +   use the cursor API to reach a specific point of the document and then obtain
    +   an InputRange from that point.
    +/
    XMLCursor!T cursor;
    alias cursor this;

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
        if (hasChildren())
            enter();
        else if (hasSibling())
            next();
        else
            exit();
    }
    
    static if (isSavableLowLevelParser!T)
        typeof(this) save() const;
}