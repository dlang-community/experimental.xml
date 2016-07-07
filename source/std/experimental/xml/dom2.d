/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   An implementation of the W3C DOM Level 3 specification.
+   It tries to differ as little as practically possible from the specification,
+   while also adding some useful and more idiomatic constructs.
+/

/*
* Things marked with OK are correctly implemented;
* Things marked with CHECKED have been tested;
* Everything else shall not be relied upon.
*/

module std.experimental.xml.dom2;

import std.variant: Variant;
alias UserData = Variant;

import std.typecons: rebindable;

enum NodeType: ushort // OK
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
enum DocumentPosition: ushort // OK
{
    DISCONNECTED,
    PRECEDING,
    FOLLOWING,
    CONTAINS,
    CONTAINED_BY,
    IMPLEMENTATION_SPECIFIC,
}
enum UserDataOperation: ushort // OK
{
    NODE_CLONED,
    NODE_IMPORTED,
    NODE_DELETED,
    NODE_RENAMED,
    NODE_ADOPTED,
}

enum ExceptionCode: ushort // OK
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
class DOMException: Exception // OK
{
    ExceptionCode code;
    this(ExceptionCode code)
    {
        import std.conv: to;
        super(to!string(code));
        this.code = code;
    }
}

alias UserDataHandler(StringType, alias Alloc) = void delegate(UserDataOperation, string, UserData, Node!(StringType, Alloc), Node!(StringType, Alloc)); // OK

abstract class Node(StringType, alias Alloc)
{
    import std.experimental.xml.interfaces: UsesAllocator;
    mixin UsesAllocator!Alloc;
    
    // REQUIRED BY THE STANDARD; TO BE IMPLEMENTED BY SUBCLASSES
    public abstract
    {
        @property StringType    namespaceUri()    const ;
        @property StringType    nodeName()        const ;
        @property NodeType      nodeType()        const ;
    }
    // REQUIRED BY THE STANDARD; USE DISCOURAGED
    public deprecated // OK
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
        @property NamedNodeMap!(StringType, Alloc) attributes() { return null; }
        @property StringType localName() const  { return null; }
        @property StringType nodeValue() { return null; }
        @property void nodeValue(StringType newValue) {}
        @property StringType prefix() const  { return null; }
        @property void prefix(StringType newValue) {}
        @property StringType baseUri() { return parentNode.baseUri(); }

        bool hasAttributes() { return false; }

        @property StringType textContent() const // OK
        {
            StringType result = [];
            for (auto child = rebindable(firstChild); child !is null; child = child.nextSibling)
                if (child.nodeType != NodeType.PROCESSING_INSTRUCTION && child.nodeType != NodeType.COMMENT)
                    result ~= child.textContent;
            return result;
        }
        @property void textContent(StringType newValue) // OK
        {
            while (firstChild)
                removeChild(firstChild);
            appendChild(ownerDocument.createTextNode(newValue));
        }

        Node insertBefore(Node newChild, Node refChild) // OK
        {
            if (newChild.ownerDocument !is ownerDocument)
                throw new DOMException(ExceptionCode.WRONG_DOCUMENT);
            if (this is newChild || newChild.isAncestor(this) || newChild is refChild)
                throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
            if (refChild.parentNode !is this)
                throw new DOMException(ExceptionCode.NOT_FOUND);
            if (newChild.parentNode !is null)
                newChild.parentNode.removeChild(newChild);
            newChild._parentNode = this;
            if (refChild.previousSibling)
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
        Node replaceChild(Node newChild, Node oldChild) // OK
        {
            if (newChild.ownerDocument !is ownerDocument)
                throw new DOMException(ExceptionCode.WRONG_DOCUMENT);
            if (this is newChild || newChild.isAncestor(this))
                throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
            if (oldChild.parentNode !is this)
                throw new DOMException(ExceptionCode.NOT_FOUND);
            if (newChild.parentNode !is null)
                newChild.parentNode.removeChild(newChild);
            removeChild(oldChild);
            newChild._parentNode = this;
            if (oldChild.previousSibling)
            {
                oldChild.previousSibling._nextSibling = newChild;
                newChild._previousSibling = oldChild.previousSibling;
                oldChild._previousSibling = null;
            }
            if (oldChild.nextSibling)
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
        Node appendChild(Node newChild) // OK
        {
            if (newChild.ownerDocument !is ownerDocument)
                throw new DOMException(ExceptionCode.WRONG_DOCUMENT);
            if (this is newChild || newChild.isAncestor(this))
                throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
            if (newChild.parentNode !is null)
                newChild.parentNode.removeChild(newChild);
            newChild._parentNode = this;
            if (lastChild)
            {
                newChild._previousSibling = lastChild;
                lastChild._nextSibling = newChild;
            }
            else
                _firstChild = newChild;
            _lastChild = newChild;
            return newChild;
        }

        Node cloneNode(bool deep) { return null; }
        void normalize() {}

        bool isSupported(string feature, string version_) const { return false; }

        DocumentPosition compareDocumentPosition(Node other) { return DocumentPosition.PRECEDING; }
        StringType lookupPrefix(StringType namespaceUri) { return null; }
        bool isDefaultNamespace(StringType prefix) { return false; }
        bool isEqualNode(Node arg) { return false; }
        Object getFeature(string feature, string version_) { return null; }

        UserData setUserData(string key, UserData data, UserDataHandler!(StringType, Alloc) handler)
        {
            userData[key] = data;
            if (handler)
                userDataHandlers[key] = handler;
            return data;
        }
        UserData getUserData(string key) const // OK
        {
            if (key in userData)
                return userData[key];
            return Variant(null);
        }
    }
    // REQUIRED BY THE STANDARD; SHOULD NOT BE OVERRIDDEN
    public final
    {
        @property NodeList!(StringType, Alloc) childNodes()
        {
            class ChildNodeList: NodeList!(StringType, Alloc)
            {
                private Node parent;
                override Node item(size_t index)
                {
                    auto result = rebindable(parent.firstChild);
                    for (size_t i = 0; i < index && result !is null; i++)
                    {
                        result = result.nextSibling;
                    }
                    return result;
                }
                override @property size_t length() const
                {
                    auto child = rebindable(parent.firstChild);
                    size_t result = 0;
                    while (child)
                    {
                        result++;
                        child = child.nextSibling;
                    }
                    return result;
                }
                Node opIndex(size_t i) { return item(i); }
            }
            import std.experimental.allocator;
            auto cnl = _p_alloc.make!ChildNodeList();
            cnl.parent = this;
            return cnl;
        }
        @property auto firstChild() inout { return _firstChild; } // OK
        @property auto lastChild() inout { return _lastChild; } // OK
        @property auto nextSibling() inout { return _nextSibling; } // OK
        @property auto ownerDocument() inout { return _ownerDocument; } // OK
        @property auto parentNode() inout { return _parentNode; } // OK
        @property auto previousSibling() inout { return _previousSibling; } // OK

        bool hasChildNodes() const // OK
        {
            return _firstChild !is null;
        }
        deprecated bool isSameNode(in Node other) // OK
        {
            return this is other;
        }
        Node removeChild(Node oldChild) // OK
        {
            if (oldChild.parentNode !is this)
                throw new DOMException(ExceptionCode.NOT_FOUND);

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
    private Document!(StringType, Alloc) _ownerDocument;
    private UserData[string] userData;
    private UserDataHandler!(StringType, Alloc)[string] userDataHandlers;

    // NOT REQUIRED BY THE STANDARD; SHOULD NOT BE OVERRIDDEN
    public final
    {
        void removeFromParent() // OK
        {
            if (_parentNode)
                parentNode.removeChild(this);
        }
        bool isAncestor(in Node other) const // OK
        {
            for (auto child = rebindable(firstChild); child !is null; child = child.nextSibling)
            {
                if (child is other)
                    return true;
                if (child.isAncestor(other))
                    return true;
            }
            return false;
        }
    }
}

class Attr(StringType, alias Alloc): Node!(StringType, Alloc)
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public // OK
    {
        @property auto name() const { return _name; } // OK
        @property auto specified() const { return _specified; } // OK
        @property auto ownerElement() const { return _ownerElement; } // OK
        @property auto schemaTypeInfo() const { return _schemaTypeInfo; } // OK
        @property auto isId() const { return _isId; } // OK

        @property StringType value() const // OK
        {
            StringType result = [];
            auto child = rebindable(firstChild);
            while (child)
            {
                result ~= child.textContent;
                child = child.nextSibling;
            }
            return result;
        }
        @property void value(StringType newValue) // OK
        {
            auto child = firstChild;
            while (child)
            {
                auto nextChild = child.nextSibling;
                child.removeFromParent;
                child = nextChild;
            }
            auto newChild = ownerDocument.createTextNode(newValue);
            newChild._parentNode = this;
            _lastChild = newChild;
            _firstChild = _lastChild;
        }
    }
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property StringType localName() const
        {
            if (_prefix_end > 0)
                return _name[(_prefix_end + 1)..$];
            else
                return name;
        }
        @property StringType nodeName() const { return name; }
        @property NodeType nodeType() const { return NodeType.ATTRIBUTE; }
        @property StringType nodeValue() { return value; }
        @property void nodeValue(StringType newValue) { value = newValue; }
        @property StringType prefix() const  { return name[0.._prefix_end]; }
        @property void prefix(StringType newPrefix)
        {
            _name = newPrefix ~ ':' ~ localName;
            _prefix_end = newPrefix.length;
        }
        @property StringType textContent() const { return value; }
        @property void textContent(StringType newContent) { value = newContent; }

        @property StringType namespaceUri() const  { return _namespaceUri; }
    }
    private
    {
        StringType _name, _namespaceUri;
        size_t _prefix_end;
        bool _specified, _isId;
        Element!(StringType, Alloc) _ownerElement;
        TypeInfo _schemaTypeInfo;
    }
}

abstract class CharacterData(StringType, alias Alloc): Node!(StringType, Alloc)
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
                throw new DOMException(ExceptionCode.INDEX_SIZE);

            import std.algorithm: min;
            data = data[0..offset] ~ data[min(offset + count, length)..$];
        }
        void insertData(size_t offset, StringType arg)
        {
            if (offset > length)
                throw new DOMException(ExceptionCode.INDEX_SIZE);

            data = data[0..offset] ~ arg ~ data[offset..$];
        }
        void replaceData(size_t offset, size_t count, StringType arg)
        {
            if (offset > length)
                throw new DOMException(ExceptionCode.INDEX_SIZE);

            import std.algorithm: min;
            data = data[0..offset] ~ arg ~ data[min(offset + count, length)..$];
        }
        auto substringData(size_t offset, size_t count) const
        {
            if (offset > length)
                throw new DOMException(ExceptionCode.INDEX_SIZE);

            import std.algorithm: min;
            return data[offset..min(offset + count, length)];
        }
    }
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property StringType nodeValue() const { return data; }
        @property void nodeValue(StringType newValue) { data = newValue; }
        @property StringType textContent() const { return data; }
        @property void textContent(StringType newValue) { data = newValue; }

        Node!(StringType, Alloc) insertBefore(Node!(StringType, Alloc) newChild,  Node!(StringType, Alloc) refChild)
        {
            throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
        }
        Node!(StringType, Alloc) replaceChild(Node!(StringType, Alloc) newChild,  Node!(StringType, Alloc) oldChild)
        {
            throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
        }
        Node!(StringType, Alloc) appendChild(Node!(StringType, Alloc) newChild)
        {
            throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
        }

        @property StringType namespaceUri() const  { return null;}
    }
}

class Comment(StringType, alias Alloc): CharacterData!(StringType, Alloc)
{
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property NodeType nodeType() const  { return NodeType.COMMENT; }
        @property StringType nodeName() const  { return "#comment"; }
    }
}

class Text(StringType, alias Alloc): CharacterData!(StringType, Alloc)
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        @property auto isElementContentWhitespace() const { return false; } // <-- TODO!
        @property StringType wholeText() const { return []; }
        Text replaceWholeText(StringType newContent) { return null; } // <-- TODO!
        Text splitText(size_t offset)
        {
            if (offset > length)
                throw new DOMException(ExceptionCode.INDEX_SIZE);

            data = data[0..offset];
            Text newNode = ownerDocument.createTextNode(data[offset..$]);
            if (parentNode)
            {
                newNode._parentNode = parentNode;
                newNode._previousSibling = this;
                newNode._nextSibling = nextSibling;
                nextSibling._previousSibling = newNode;
                _nextSibling = newNode;
            }
            return newNode;
        }
    }
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property NodeType nodeType() const  { return NodeType.TEXT; }
        @property StringType nodeName() const  { return "#text"; }
    }
}

class CDATASection(StringType, alias Alloc): Text!(StringType, Alloc)
{
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property NodeType nodeType() const  { return NodeType.CDATA_SECTION; }
        @property StringType nodeName() const  { return "#cdata-section"; }
    }
}

class ProcessingInstruction(StringType, alias Alloc): Node!(StringType, Alloc)
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        StringType target;
        StringType data;
    }
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property NodeType nodeType() const  { return NodeType.PROCESSING_INSTRUCTION; }
        @property StringType nodeName() const  { return target; }
        @property StringType namespaceUri() const  { return null; }
    }
}

class EntityReference(StringType, alias Alloc): Node!(StringType, Alloc)
{
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property NodeType nodeType() const  { return NodeType.ENTITY_REFERENCE; }
        @property StringType nodeName() const  { return null; }
    }
}

class Entity(StringType, alias Alloc): Node!(StringType, Alloc)
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
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property NodeType nodeType() const  { return NodeType.ENTITY; }
        @property StringType nodeName() const  { return null; }
    }
}

class Notation(StringType, alias Alloc): Node!(StringType, Alloc)
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        const StringType publicId;
        const StringType systemId;
    }
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property NodeType nodeType() const  { return NodeType.NOTATION; }
        @property StringType nodeName() const  { return null; }
    }
}

class DocumentType(StringType, alias Alloc): Node!(StringType, Alloc)
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        const StringType name;
        const NamedNodeMap!(StringType, Alloc) entities;
        const StringType publicId;
        const StringType systemId;
        const StringType internalSubset;
    }
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property NodeType nodeType() const  { return NodeType.DOCUMENT_TYPE; }
        @property StringType nodeName() const  { return name; }
    }
}

class Element(StringType, alias Alloc): Node!(StringType, Alloc)
{
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        @property auto tagName() const { return _name; }
        @property auto schemaTypeInfo() const { return _schemaTypeInfo; }

        StringType getAttribute(StringType name)
        {
            return _attributes.getNamedItem(name).nodeValue;
        }
        StringType getAttributeNS(StringType namespaceUri,  StringType localName)
        {
            return _attributes.getNamedItemNS(namespaceUri, localName).nodeValue;
        }
        Attr!(StringType, Alloc) getAttributeNode(StringType name)
        {
            return cast(Attr!(StringType, Alloc))(_attributes.getNamedItem(name));
        }
        Attr!(StringType, Alloc) getAttributeNodeNS(StringType namespaceUri,  StringType localName)
        {
            return cast(Attr!(StringType, Alloc))(_attributes.getNamedItemNS(namespaceUri, localName));
        }

        void setAttribute(StringType name, StringType value)
        {
            auto attr = ownerDocument.createAttribute(name);
            attr.value = value;
            _attributes.setNamedItem(attr);
        }
        void setAttributeNS(StringType namespaceUri, StringType qualifiedName, StringType value)
        {
            auto attr = ownerDocument.createAttributeNS(namespaceUri, qualifiedName);
            attr.value = value;
            _attributes.setNamedItemNS(attr);
        }
        Attr!(StringType, Alloc) setAttributeNode(Attr!(StringType, Alloc) newAttr)
        {
            return cast(Attr!(StringType, Alloc))(_attributes.setNamedItem(newAttr));
        }
        Attr!(StringType, Alloc) setAttributeNodeNS(Attr!(StringType, Alloc) newAttr)
        {
            return cast(Attr!(StringType, Alloc))(_attributes.setNamedItemNS(newAttr));
        }

        void removeAttribute(StringType name)
        {
            _attributes.removeNamedItem(name);
        }
        void removeAttributeNS(StringType namespaceUri,  StringType localName)
        {
            _attributes.removeNamedItemNS(namespaceUri, localName);
        }
        Attr!(StringType, Alloc) removeAttributeNode(Attr!(StringType, Alloc) oldAttr) { return null; }

        NodeList!(StringType, Alloc) getElementsByTagName(StringType name) const { return null; }
        NodeList!(StringType, Alloc) getElementsByTagNameNS(StringType namespaceUri,  StringType localName) const { return null; }

        bool hasAttribute(StringType name) const { return false; }
        bool hasAttributeNS(StringType namespaceUri,  StringType localName) const { return false; }

        void setIdAttribute(StringType name,  bool isId) {}
        void setIdAttributeNS(StringType namespaceUri,  StringType localName,  bool isId) {}
        void setIdAttributeNode(Attr!(StringType, Alloc) idAttr,  bool isId) {}
    }
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property StringType localName() const
        {
            if (_prefix_end > 0)
                return tagName[_prefix_end..$];
            else
                return null;
        }
        @property StringType nodeName() const  { return tagName; }
        @property StringType prefix() const  { return tagName[0.._prefix_end]; }
        @property void prefix(StringType newPrefix)
        {
            _name = newPrefix ~ localName;
            _prefix_end = newPrefix.length;
        }
        bool hasAttributes()
        {
            return _attributes !is null && _attributes.length > 0;
        }
        @property StringType baseUri()
        {
            auto base = getAttributeNS("http://www.w3.org/XML/1998/namespace", "base");
            if (base !is null)
                return base;
            else
                return parentNode.baseUri();
        }
        @property StringType namespaceUri() const { return _namespaceUri; }
        @property NodeType nodeType() const { return NodeType.ELEMENT; }
    }
    private
    {
        StringType _name;
        size_t _prefix_end;
        TypeInfo _schemaTypeInfo;
        NamedNodeMap!(StringType, Alloc) _attributes;
        StringType _namespaceUri;
    }
    package(std) this()
    {
        _attributes = new NamedNodeMapImpl_ElementAttributes!(StringType, Alloc);
    }
}

class Document(StringType, alias Alloc): Node!(StringType, Alloc)
{
    import std.experimental.allocator;
    
    // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
    public
    {
        const DocumentType!(StringType, Alloc) doctype;
        const DOMImplementation implementation;
        const Element!(StringType, Alloc) documentElement;

        Element!(StringType, Alloc) createElement(StringType tagName)
        {
            auto result = _p_alloc.make!(Element!(StringType, Alloc))();
            result._ownerDocument = this;
            result._name = tagName;
            return result;
        }
        Element!(StringType, Alloc) createElementNS(StringType namespaceUri, StringType qualifiedName)
        {
            import std.experimental.xml.faststrings: fastIndexOf;

            auto result = _p_alloc.make!(Element!(StringType, Alloc))();
            result._ownerDocument = this;
            result._namespaceUri = namespaceUri;
            result._name = qualifiedName;
            auto pos = fastIndexOf(qualifiedName, ':');
            result._prefix_end = pos >= 0 ? pos : 0;
            return result;
        }
        Text!(StringType, Alloc) createTextNode(StringType text)
        {
            auto result = _p_alloc.make!(Text!(StringType, Alloc))();
            result._ownerDocument = this;
            result.data = text;
            return result;
        }
        Comment!(StringType, Alloc) createComment(StringType text)
        {
            auto result = _p_alloc.make!(Comment!(StringType, Alloc))();
            result._ownerDocument = this;
            result.data = text;
            return result;
        }
        CDATASection!(StringType, Alloc) createCDataSection(StringType text)
        {
            auto result = _p_alloc.make!(CDATASection!(StringType, Alloc))();
            result._ownerDocument = this;
            result.data = text;
            return result;
        }
        ProcessingInstruction!(StringType, Alloc) createProcessingInstruction(StringType target, StringType data)
        {
            auto result = _p_alloc.make!(ProcessingInstruction!(StringType, Alloc))();
            result._ownerDocument = this;
            result.target = target;
            result.data = data;
            return result;
        }
        Attr!(StringType, Alloc) createAttribute(StringType name)
        {
            auto result = _p_alloc.make!(Attr!(StringType, Alloc))();
            result._ownerDocument = this;
            result._name = name;
            return result;
        }
        Attr!(StringType, Alloc) createAttributeNS(StringType namespaceUri, StringType qualifiedName)
        {
            import std.experimental.xml.faststrings: fastIndexOf;

            auto result = _p_alloc.make!(Attr!(StringType, Alloc))();
            result._ownerDocument = this;
            result._namespaceUri = namespaceUri;
            result._name = qualifiedName;
            auto pos = fastIndexOf(qualifiedName, ':');
            result._prefix_end = pos >= 0 ? pos : 0;
            return result;
        }
        EntityReference!(StringType, Alloc) createEntityReference(StringType name) const { return null; }

        NodeList!(StringType, Alloc) getElementsByTagName(StringType tagName) { return null; }
        NodeList!(StringType, Alloc) getElementsByTagNameNS(StringType namespaceUri, StringType tagName) { return null; }
        Node!(StringType, Alloc) getElementById(StringType elementId) { return null; }

        Node!(StringType, Alloc) importNode(Node!(StringType, Alloc) node, bool deep) { return null; }
        Node!(StringType, Alloc) adoptNode(Node!(StringType, Alloc) source) { return null; }
        Node!(StringType, Alloc) renameNode(Node!(StringType, Alloc) n, StringType namespaceUri, StringType qualifiedName) { return null; }

        const StringType inputEncoding;
        const StringType xmlEncoding;
        const DOMConfiguration domConfig;

        @property bool xmlStandalone() { return false; }
        @property void xmlStandalone(bool val) {}
        @property StringType xmlVersion() { return null; }
        @property void xmlVersion(StringType val) {}

        bool strictErrorChecking = true;
        StringType documentURI;

        void normalizeDocument() {}
    }
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property StringType baseUri() const { return null; }
        @property StringType namespaceUri() const { return null; }
        @property StringType nodeName() const { return "#document"; }
        @property NodeType nodeType() const { return NodeType.DOCUMENT; }
    }
}

class DocumentFragment(StringType, alias Alloc): Node!(StringType, Alloc)
{
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        @property NodeType nodeType() const  { return NodeType.DOCUMENT_FRAGMENT; }
        @property StringType nodeName() const  { return "#document-fragment"; }
    }
}

abstract class NodeList(StringType, alias Alloc)
{
    // REQUIRED BY THE STANDARD
    public
    {
        abstract ulong length();
        abstract Node!(StringType, Alloc) item(ulong index);
    }
}

abstract class NamedNodeMap(StringType, alias Alloc)
{
    // REQUIRED BY THE STANDARD
    public
    {
        abstract ulong length() const ;
        abstract Node!(StringType, Alloc) item(ulong index);

        abstract Node!(StringType, Alloc) getNamedItem(StringType name);
        abstract Node!(StringType, Alloc) setNamedItem(Node!(StringType, Alloc) arg);
        abstract Node!(StringType, Alloc) removeNamedItem(StringType name);

        abstract Node!(StringType, Alloc) getNamedItemNS(StringType namespaceUri, StringType localName) ;
        abstract Node!(StringType, Alloc) setNamedItemNS(Node!(StringType, Alloc) arg);
        abstract Node!(StringType, Alloc) removeNamedItemNS(StringType namespaceUri, StringType localName);
    }
}

private class NamedNodeMapImpl_ElementAttributes(StringType, alias Alloc): NamedNodeMap!(StringType, Alloc)
{
    import std.typecons: Tuple;
    
    // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
    public override
    {
        ulong length() const
        {
            return attrs.length;
        }
        Attr!(StringType, Alloc) item(ulong index)
        {
            if (index < attrs.keys.length)
                return *(attrs.keys[index] in attrs);
            else
                return null;
        }

        Attr!(StringType, Alloc) getNamedItem(StringType name)
        {
            return getNamedItemNS(null, name);
        }
        Attr!(StringType, Alloc) setNamedItem(Node!(StringType, Alloc) arg)
        {
            return setNamedItemNS(arg);
        }
        Attr!(StringType, Alloc) removeNamedItem(StringType name)
        {
            return removeNamedItemNS(null, name);
        }

        Attr!(StringType, Alloc) getNamedItemNS(StringType namespaceUri, StringType localName)
        {
            auto key = Key(namespaceUri, localName);
            if (key in attrs)
                return *(key in attrs);
            else
                return null;
        }
        Attr!(StringType, Alloc) setNamedItemNS(Node!(StringType, Alloc) arg)
        {
            Attr!(StringType, Alloc) attr = cast(Attr!(StringType, Alloc))arg;
            auto key = Key(attr.namespaceUri, attr.localName);
            auto oldAttr = (key in attrs) ? *(key in attrs) : null;
            attrs[key] = attr;
            return oldAttr;
        }
        Attr!(StringType, Alloc) removeNamedItemNS(StringType namespaceUri, StringType localName)
        {
            auto key = Key(namespaceUri, localName);
            if (key in attrs)
            {
                auto result = attrs.get(key, null);
                attrs.remove(key);
                return result;
            }
            else
                throw new DOMException(ExceptionCode.NOT_FOUND);
        }
    }
    private alias Key = Tuple!(StringType, "namespaceUri", StringType, "localName");
    private Attr!(StringType, Alloc)[Key] attrs;
}

struct DOMImplementation
{
}

struct DOMConfiguration
{
}

unittest
{
    import std.experimental.allocator.gc_allocator;
    import std.experimental.allocator.mallocator;
    auto document = new Document!(string, Mallocator);
    auto element = document.createElement("myElement");
    element.setAttribute("myAttribute", "myValue");
    assert(element.getAttribute("myAttribute") == "myValue");
    auto text = document.createTextNode("Some useful insight...");
    element.appendChild(text);
    assert(element.childNodes.item(0).textContent == "Some useful insight...");
}