
/++
+   An implementation of the W3C DOM Level 3 specification.
+   It tries to differ as little as practically possible from the specification,
+   while also adding some useful and more idiomatic construct.
+/

module std.experimental.dom;

// COMMENTED BECAUSE IT IS INCOMPLETE
/*
import std.variant: Variant;
alias DOMUserData = Variant;

enum NodeType
{
    ELEMENT = 1,
    ATTRIBUTE,
    TEXT,
    CDATA_SECTION,
    ENTITY_REFERENCE,
    ENTITY,
    PROCESSING_INSTRUCTION,
    COMMENT,
    DOCUMENT,
    DOCUMENT_TYPE,
    DOCUMENT_FRAGMENT,
    NOTATION,
}
enum DocumentPosition
{
    DISCONNECTED,
    PRECEDING,
    FOLLOWING,
    CONTAINS,
    CONTAINED_BY,
    IMPLEMENTATION_SPECIFIC
}
class Node(StringType)
{
    // REQUIRED BY THE STANDARD; TO BE IMPLEMENTED BY SUBCLASSES
    public abstract
    {
        @property StringType    baseUri()         const;
        @property StringType    namespaceUri()    const;
        @property StringType    nodeName()        const;
        @property NodeType      nodeType()        const;
    }
    // REQUIRED BY THE STANDARD; USE DISCOURAGED
    public deprecated
    {
        // aliases to members of NodeType
        enum NodeType ELEMENT_NODE                = NodeType.ELEMENT;
        enum NodeType ATTRIBUTE_NODE              = NodeType.ATTRIBUTE;
        enum NodeType TEXT_NODE                   = NodeType.TEXT;
        enum NodeType CDATA_SECTION_NODE          = NodeType.CDATA_SECTION;
        enum NodeType ENTITY_REFERENCE_NODE       = NodeType.ENTITY_REFERENCE;
        enum NodeType ENTITY_NODE                 = NodeType.ENTITY;
        enum NodeType PROCESSING_INSTRUCTION_NODE = NodeType.PROCESSING_INSTRUCTION;
        enum NodeType COMMENT_NODE                = NodeType.COMMENT;
        enum NodeType DOCUMENT_NODE               = NodeType.DOCUMENT;
        enum NodeType DOCUMENT_TYPE_NODE          = NodeType.DOCUMENT_TYPE;
        enum NodeType DOCUMENT_FRAGMENT_NODE      = NodeType.DOCUMENT_FRAGMENT;
        enum NodeType NOTATION_NODE               = NodeType.NOTATION;
        
        // aliases to members of DocumentPosition
        enum DocumentPosition DOCUMENT_POSITION_DISCONNECTED            = DocumentPosition.DISCONNECTED;
        enum DocumentPosition DOCUMENT_POSITION_PRECEDING               = DocumentPosition.PRECEDING;
        enum DocumentPosition DOCUMENT_POSITION_FOLLOWING               = DocumentPosition.FOLLOWING;
        enum DocumentPosition DOCUMENT_POSITION_CONTAINS                = DocumentPosition.CONTAINS;
        enum DocumentPosition DOCUMENT_POSITION_CONTAINED_BY            = DocumentPosition.CONTAINED_BY;
        enum DocumentPosition DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = DocumentPosition.IMPLEMENTATION_SPECIFIC;
    }
    // REQUIRED BY THE STANDARD; IMPLEMENTED HERE, CAN BE OVERRIDDEN
    public
    {
        @property NamedNodeMap attributes() const { return null; }
        @property StringType localName() const { return null; }
        @property StringType nodeValue() const { return null; }
        @property void nodeValue(StringType newValue) {}
        @property StringType prefix() const { return null; }
        @property StringType prefix(StringType newValue) {}
        
        @property auto textContent() const
        {
            StringType result = [];
            for (auto child = firstChild; child !is null; child = child.nextSibling)
                if (child.nodeType != NodeType.PROCESSING_INSTRUCTION && child.nodeType != NodeType.COMMENT)
                    result ~= child.textContent;
            return result;
        }
        @property void textContent(StringType newValue)
        {
            while (firstChild != null)
                removeChild(firstChild);
            appendChild(ownerDocument.createTextNode(newValue));
        }
        
        Node insertBefore(in Node newChild, in Node refChild)
        {
            if (newChild.ownerDocument !is ownerDocument)
                throw new DOMException(ErrorCode.WRONG_DOCUMENT);
            if (newChild is this || newChild.isAncestor(this) || newChild is refChild)
                throw new DOMException(ErrorCode.HIERARCHY_REQUEST);
            if (refChild.parent !is this)
                throw new DOMException(ErrorCode.NOT_FOUND);
            newChild.remove();
            newChild._parentNode = this;
            if (refChild.previousSibling !is null)
            {
                refChild.previousSibling._nextSibling = newChild;
                newChild._previousSibling = refChild.previousSibling;
            }
            refChild._previousSibling = newChild;
            newChild._nextSibling = refChild;
            if (firstChild is refChild)
                _firstChild = newChild;
            return newChild;
        }
        Node replaceChild(in Node newChild, in Node oldChild)
        {
            if (newChild.ownerDocument !is ownerDocument)
                throw new DOMException(ErrorCode.WRONG_DOCUMENT);
            if (newChild is this || newChild.isAncestor(this))
                throw new DOMException(ErrorCode.HIERARCHY_REQUEST);
            if (oldChild.parent !is this)
                throw new DOMException(ErrorCode.NOT_FOUND);
            newChild.remove();
            newChild._parentNode = this;
            oldChild._parentNode = null;
            if (oldChild.previousSibling !is null)
            {
                oldChild.previousSibling._nextSibling = newChild;
                newChild._previousSibling = oldChild.previousSibling;
                oldChild._previousSibling = null;
            }
            if (oldChild.nextSibling !is null)
            {
                oldChild.nextSibling._previousSibling = newChild;
                newChild._nextSibling = oldChild.nextSibling;
                oldChild._nextSibling = null;
            }
            if (oldChild is firstChild)
                _firstChild = newChild;
            if (oldChild is lastChild)
                _lastChild = newChild;
            return oldChild;
        }
        Node appendChild(in Node newChild)
        {
            if (newChild.ownerDocument !is ownerDocument)
                throw new DOMException(ErrorCode.WRONG_DOCUMENT);
            if (newChild is this || newChild.isAncestor(this))
                throw new DOMException(ErrorCode.HIERARCHY_REQUEST);
            newChild.remove();
            newChild._parentNode = this;
            if (lastChild !is null)
            {
                newChild._previousSibling = lastChild;
                lastChild._nextSibling = newChild;
            }
            else
                firstChild = newChild;
            lastChild = newChild;
        }
        
        Node cloneNode(in bool deep) const;
        void normalize();
        
        boolean isSupported(in string feature, in string version_);
        
        DocumentPosition compareDocumentPosition(in Node other) const;
        StringType lookupPrefix(in StringType namespaceUri);
        bool isDefaultNamespace(in StringType prefix) const;
        bool isEqualNode(in Node arg) const;
        Object getFeature(in string feature, in string version_);
        DOMUserData setUserData(in string key, in DOMUserData data, in UserDataHandler handler);
        DOMUserData getUserData(in string key);
    }
    // REQUIRED BY THE STANDARD; SHOULD NOT BE OVERRIDDEN
    public final
    {
        @property NodeList!StringType childNodes() const
        {
            return new class NodeList!StringType
            {
                Node item(in size_t index) const
                {
                    auto result = firstChild;
                    for (size_t i = 0; i < index && result !is null; i++)
                    {
                        result = result.nextSibling;
                    }
                    return result;
                }
                @property size_t length() const
                {
                    auto child = firstChild;
                    size_t result = 0;
                    while (child !is null)
                    {
                        result++;
                        child = child.nextSibling;
                    }
                    return result;
                }
                Node opIndex(size_t i) const { return item(i); }
            };
        }
        @property Node firstChild() const { return _firstChild; }
        @property Node lastChild() const { return _lastChild; }
        @property Node nextSibling() const { return _nextSibling; }
        const Document ownerDocument;
        @property Node parentNode() const { return _parentNode; }
        @property Node previousSibling() const { return _previousSibling; }
        
        bool hasAttributes() const
        {
            return attributes !is null && attributes.length > 0;
        }
        bool hasChildNodes() const
        {
            return firstChild !is null;
        }
        bool isSameNode(in Node other) const
        {
            return this is other;
        }
        Node removeChild(in Node oldChild)
        {
            if (oldChild.parent !is this)
                throw new DOMException(ErrorCode.NOT_FOUND);
            
            if (oldChild is firstChild)
                _firstChild = oldChild.nextSibling;
            else
                oldChild.previousSibling._nextSibling = oldChild.nextSibling;
                
            if (oldChild is lastChild)
                _lastChild = oldChild.previousSibling;
            else
                oldChild.nextSibling._previousSibling = oldChild.previousSibling;
                
            oldChild._parentNode = null;
            return oldChild;
        }
    }
    private Node _parentNode, _previousSibling, _nextSibling, _firstChild, _lastChild;
    
    // NOT REQUIRED BY THE STANDARD; SHOULD NOT BE OVERRIDDEN
    public final
    {
        void remove()
        {
            if (parentNode !is null)
                parentNode.removeChild(this);
        }
    }
}

interface NodeList(StringType)
{
    // INTERFACE REQUIRED BY SPECIFICATION
    Node!StringType item(in size_t index) const;
    @property size_t length() const;
    
    // ADDITIONAL FUNCTIONALITY NOT REQUIRED BY THE SPECIFICATION
    Node!StringType opIndex(in size_t index) const;
}

enum ExceptionCode
{
    INDEX_SIZE = 1,
    DOMSTRING_SIZE,
    HIERARCHY_REQUEST,
    WRONG_DOCUMENT,
    INVALID_CHARACTER,
    NO_DATA_ALLOWED,
    NO_MODIFICATION_ALLOWED,
    NOT_FOUND,
    NOT_SUPPORTED,
    INUSE_ATTRIBUTE,
    INVALID_STATE,
    SYNTAX,
    INVALID_MODIFICATION,
    NAMESPACE,
    INVALID_ACCESS,
    VALIDATION,
    TYPE_MISMATCH,
}
class DOMException: Exception
{
    ExceptionCode code;
    this(ExceptionCode code)
    {
        this.code = code;
    }
}

class Attr(StringType): Node!StringType
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        @property auto name() const { return _name; }
        @property auto specified() const { return _specified; }
        @property auto ownerElement() const { return _ownerElement; }
        @property auto schemaTypeInfo() const { return _schemaTypeInfo; }
        @property auto isId() const { return _isId; }
        
        @property auto value() const
        {
            StringType result = [];
            Node child = firstChild;
            while (child !is null)
            {
                result ~= child.textContent;
                child = child.nextSibling;
            }
            return result;
        }
        @property void value(StringType newValue)
        {
            Node child = firstChild;
            while (child !is null)
            {
                auto nextChild = child.nextSibling;
                child.remove();
                child = nextChild;
            }
            _firstChild = _lastChild = ownerDocument.createTextNode(newValue);
        }
    }
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property auto localName() const
        {
            if (_prefix_end > 0)
                return _name[(_prefix_end + 1)..$];
            else
                return null;
        }
        @property auto nodeName() const { return name; }
        @property auto nodeType() const { return NodeType.ATTRIBUTE; }
        @property auto nodeValue() const { return value; }
        @property void nodeValue(StringType newValue) { value = newValue; }
        @property auto prefix() const { return name[0.._prefix_end]; }
        @property void prefix(StringType newPrefix)
        {
            _name = newPrefix ~ ':' ~ localName;
            _prefix_end = newPrefix.length;
        }
        @property auto textContent() const { return value; }
        @property void textContent(StringType newContent) { value = newContent; }
    }
    private
    {
        StringType _name;
        size_t _prefix_end;
        bool _specified, _isId;
        Element _ownerElement;
        TypeInfo _schemaTypeInfo;
    }
}

class CharacterData(StringType): Node!StringType
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        StringType data;
        @property auto length() const { return data.length; }
        
        void appendData(StringType arg)
        {
            data ~= arg;
        }
        void deleteData(size_t offset, size_t count)
        {
            if (offset > length)
                throw new DOMException(ErrorCode.INDEX_SIZE);
                
            import std.algorithm: min;
            data = data[0..offset] ~ data[min(offset + count, length)..$];
        }
        void insertData(size_t offset, StringType arg)
        {
            if (offset > length)
                throw new DOMException(ErrorCode.INDEX_SIZE);
                
            data = data[0..offset] ~ arg ~ data[offset..$];
        }
        void replaceData(size_t offset, size_t count, StringType arg)
        {
            if (offset > length)
                throw new DOMException(ErrorCode.INDEX_SIZE);
                
            import std.algorithm: min;
            data = data[0..offset] ~ arg ~ data[min(offset + count, length)..$];
        }
        auto substringData(size_t offset, size_t count) const
        {
            if (offset > length)
                throw new DOMException(ErrorCode.INDEX_SIZE);
                
            import std.algorithm: min;
            return data[offset..min(offset + count, length)];
        }
    }
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property auto nodeValue() const { return data; }
        @property void nodeValue(StringType newValue) { data = newValue; }
        @property auto textContent() const { return data; }
        @property void textContent(StringType newValue) { data = newValue; }
        
        Node insertBefore(in Node newChild, in Node refChild) const
        {
            throw new DOMException(ErrorCode.HIERARCHY_REQUEST);
        }
        Node replaceChild(in Node newChild, in Node oldChild) const
        {
            throw new DOMException(ErrorCode.HIERARCHY_REQUEST);
        }
        Node appendChild(in Node newChild) const
        {
            throw new DOMException(ErrorCode.HIERARCHY_REQUEST);
        }
    }
}

class Comment(StringType): CharacterData!StringType {}

class Text(StringType): CharacterData!StringType
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        @property auto isElementContentWhitespace() const { return _isElementContentWhitespace; }
        @property auto wholeText() const;
        Text replaceWholeText(StringType newContent);
        Text splitText(size_t offset)
        {
            if (offset > length)
                throw new DOMException(ErrorCode.INDEX_SIZE);
                
            data = data[0..offset];
            Text newNode = ownerDocument.createTextNode(data[offset..$]);
            if (parent !is null)
            {
                newNode._parent = parent;
                newNode._previousSibling = this;
                newNode._nextSibling = this.nextSibling;
                this.nextSibling._previousSibling = newNode;
                this._nextSibling = newNode;
            }
        }
    }
}

class CDATASection(StringType): Text!StringType {}

class ProcessingInstruction(StringType): Node!StringType
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        const StringType target;
        StringType data;
    }
}

class EntityReference(StringType): Node!StringType {}

class Entity(StringType): Node!StringType
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        const StringType publicId;
        const StringType systemId;
        const StringType notationName;
        const StringType inputEncoding;
        const StringType xmlEncoding;
        const StringType xmlVersion;
    }
}

class Notation(StringType): Node!StringType
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        const StringType publicId;
        const StringType systemId;
    }
}

class DocumentType(StringType): Node!StringType
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        const StringType name;
        const NamedNodeMap entities;
        const NamedNodeMap notations
        const StringType publicId;
        const StringType systemId;;
        const StringType internalSubset;
    }
}

class Element(StringType): Node!StringType
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        @property auto tagName() const { return _name; }
        @property auto schemaTypeInfo() const { return _schemaTypeInfo; }
        
        StringType getAttribute(in StringType name) const;
        StringType getAttributeNS(in StringType namespaceUri, in StringType localName) const;
        Attr getAttributeNode(in StringType name) const;
        Attr getAttributeNodeNS(in StringType namespaceUri, in StringType name) const;
        
        void setAttribute(in StringType name, in StringType value);
        void setAttributeNS(in StringType namespaceUri, in StringType qualifiedName, in StringType value);
        Attr setAttributeNode(in Attr newAttr);
        Attr setAttributeNodeNS(in Attr newAttr);
        
        void removeAttribute(in StringType name);
        void removeAttributeNS(in StringType namespaceUri, in StringType localName);
        Attr removeAttributeNode(in Attr oldAttr);
        
        NodeList getElementsByTagName(in StringType name) const;
        NodeList getElementsByTagNameNS(in StringType namespaceUri, in StringType localName) const;
        
        bool hasAttribute(in StringType name) const;
        bool hasAttributeNS(in StringType namespaceUri, in StringType localName) const;
        
        void setIdAttribute(in StringType name, in bool isId);
        void setIdAttributeNS(in StringType namespaceUri, in StringType localName, in bool isId);
        void setIdAttributeNode(in Attr idAttr, in bool isId);
    }
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property auto localName() const { return tagName[_prefix_end..$]; }
        @property auto nodeName() const { return tagName; }
        @property auto prefix() const { return tagName[0.._prefix_end]; }
        @property void prefix(StringType newPrefix)
        {
            _name = newPrefix ~ localName;
            _prefix_end = newPrefix.length;
        }
    }
    private
    {
        StringType _name;
        size_t _prefix_end;
        TypeInfo _schemaTypeInfo;
    }
}

struct NamedNodeMap(StringType)
{
    private Node[StringType] map;
    alias map this;
    
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        Node getNamedItem
    }
}
*/
