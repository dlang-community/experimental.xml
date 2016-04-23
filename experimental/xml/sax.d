
module experimental.xml.sax;

import experimental.xml.interfaces;
import experimental.xml.cursor;

class SAXParser(T, alias H)
    if (isLowLevelParser!T)
{
    static if (__traits(isTemplate, H))
        alias HandlerType = H!(T.CharacterType[]);
    else
        alias HandlerType = H;
        
    private XMLCursor!T cursor;
    private HandlerType handler;
    
    /++
    +   Initializes this parser (and the underlying low level one) with the given input.
    +/
    void setSource((XMLCursor!T).InputType input)
    {
        cursor.setSource(input);
    }
    
    /++ Sets the handler for this parser +/
    void setHandler(HandlerType handler)
    {
        this.handler = handler;
    }
    
    /++ Works as the corresponding method in XMLCursor. +/
    auto getName() const
    {
        return cursor.getName();
    }
    
    /++ ditto +/
    auto getLocalName() const
    {
        return cursor.getLocalName();
    }
    
    /++ ditto +/
    auto getPrefix() const
    {
        return cursor.getPrefix();
    }
    
    /++ ditto +/
    auto getAttributes() const
    {
        return cursor.getAttributes();
    }
    
    /++ ditto +/
    auto getNamespaceDefinitions() const
    {
        return cursor.getNamespaceDefinitions();
    }
    
    /++ ditto +/
    auto getText() const
    {
        return cursor.getText();
    }
    
    /++
    +   Processes the entire document; every time a node of
    +   Kind XXX is found, the corresponding method onXXX(this)
    +   of the handler is called, if it exists.
    +/
    void processDocument()
    {
        while (!cursor.endDocument())
        {
            final switch (cursor.getKind())
            {
                case DOCUMENT:
                    static if (__traits(compiles, handler.onDocument(this)))
                        handler.onDocument(this);
                    break;
                case ELEMENT_START:
                    static if (__traits(compiles, handler.onElementStart(this)))
                        handler.onElementStart(this);
                    break;
                case ELEMENT_END:
                    static if (__traits(compiles, handler.onElementEnd(this)))
                        handler.onElementEnd(this);
                    break;
                case ELEMENT_EMPTY:
                    static if (__traits(compiles, handler.onElementEmpty(this)))
                        handler.onElementEmpty(this);
                    break;
                case TEXT:
                    static if (__traits(compiles, handler.onText(this)))
                        handler.onText(this);
                    break;
                case COMMENT:
                    static if (__traits(compiles, handler.onComment(this)))
                        handler.onComment(this);
                    break;
                case PROCESSING_INSTRUCTION:
                    static if (__traits(compiles, handler.onProcessingInstruction(this)))
                        handler.onProcessingInstruction(this);
                    break;
            }
            
            if (cursor.hasChildren())
                cursor.enter();
            else if (!cursor.next())
                cursor.exit();
        }
    }
}