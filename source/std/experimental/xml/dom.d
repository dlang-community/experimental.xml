
/++
+   An implementation of the W3C DOM Level 3 specification.
+   It tries to differ as little as practically possible from the specification,
+   while also adding some useful and more idiomatic constructs.
+/

module std.experimental.xml.dom;

import std.experimental.polymorph;

import std.variant: Variant;
alias UserData = Variant;

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
    IMPLEMENTATION_SPECIFIC,
}
enum UserDataOperation
{
    NODE_CLONED,
    NODE_IMPORTED,
    NODE_DELETED,
    NODE_RENAMED,
    NODE_ADOPTED,
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
        import std.conv: to;
        super(to!string(code));
        this.code = code;
    }
}

template DOM(StringType)
{
    mixin MakePolymorphicRefCountedHierarchy!(_Node, _Attr, _CDATASection, _CharacterData, _Comment, _Document,
                                              _DocumentFragment, _DocumentType, _Element, _Entity, _EntityReference,
                                              _Notation, _ProcessingInstruction, _Text, _NodeList, _NamedNodeMap,
                                              _DOMImplementation, _DOMConfiguration);
                
    alias UserDataHandler = void delegate(UserDataOperation, string, UserData, Node, Node);
                              
    @PolymorphicWrapper("Node")
    struct _Node
    {
        mixin BaseClass;
        mixin HasDerived!(_Attr, _DocumentType, _Document, _DocumentFragment, _CharacterData,
                          _Element, _EntityReference, _Entity, _Notation, _ProcessingInstruction);
        
        // REQUIRED BY THE STANDARD; TO BE IMPLEMENTED BY SUBCLASSES
        public
        {
            @property StringType    baseUri()         const { return assertAbstract!StringType; }
            @property StringType    namespaceUri()    const { return assertAbstract!StringType; }
            @property StringType    nodeName()        const { return assertAbstract!StringType; }
            @property NodeType      nodeType()        const { return assertAbstract!NodeType; }
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
            @property NamedNodeMap attributes() const { return NamedNodeMap.Null; }
            @property StringType localName() const { return null; }
            @property StringType nodeValue() const { return null; }
            @property void nodeValue(StringType newValue) {}
            @property StringType prefix() const { return null; }
            @property void prefix(StringType newValue) {}
            
            bool hasAttributes() const { return false; }
            
            @property StringType textContent() const
            {
                StringType result = [];
                for (Node child = cast(Node)firstChild; !child.isNull; child = child.nextSibling)
                    if (child.nodeType != NodeType.PROCESSING_INSTRUCTION && child.nodeType != NodeType.COMMENT)
                        result ~= child.textContent;
                return result;
            }
            @property void textContent(StringType newValue)
            {
                while (firstChild)
                    removeChild(firstChild);
                appendChild(cast(Node)ownerDocument.createTextNode(newValue));
            }
            
            Node insertBefore(Node newChild, Node refChild)
            {
                if (newChild.ownerDocument != ownerDocument)
                    throw new DOMException(ExceptionCode.WRONG_DOCUMENT);
                if (isSameNode(newChild) || newChild.isAncestor(Node.getWrapperOf(this)) || newChild == refChild)
                    throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
                if (!isSameNode(refChild.parentNode))
                    throw new DOMException(ExceptionCode.NOT_FOUND);
                newChild.parentNode.removeChild(newChild);
                newChild.unwrap._parentNode = Node.getWrapperOf(this);
                if (refChild.previousSibling)
                {
                    refChild.previousSibling.unwrap._nextSibling = newChild;
                    newChild.unwrap._previousSibling = refChild.previousSibling;
                }
                refChild.unwrap._previousSibling = newChild;
                newChild.unwrap._nextSibling = refChild;
                if (firstChild == refChild)
                    _firstChild = newChild;
                return newChild;
            }
            Node replaceChild(Node newChild, Node oldChild)
            {
                if (newChild.ownerDocument != ownerDocument)
                    throw new DOMException(ExceptionCode.WRONG_DOCUMENT);
                if (isSameNode(newChild) || newChild.isAncestor(Node.getWrapperOf(this)))
                    throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
                if (!isSameNode(oldChild.parentNode))
                    throw new DOMException(ExceptionCode.NOT_FOUND);
                newChild.parentNode.removeChild(newChild);
                newChild.unwrap._parentNode = Node.getWrapperOf(this);
                oldChild.unwrap._parentNode = Node.Null;
                if (oldChild.previousSibling)
                {
                    oldChild.previousSibling.unwrap._nextSibling = newChild;
                    newChild.unwrap._previousSibling = oldChild.previousSibling;
                    oldChild.unwrap._previousSibling = Node.Null;
                }
                if (oldChild.nextSibling)
                {
                    oldChild.nextSibling.unwrap._previousSibling = newChild;
                    newChild.unwrap._nextSibling = oldChild.nextSibling;
                    oldChild.unwrap._nextSibling = Node.Null;
                }
                if (oldChild == firstChild)
                    _firstChild = newChild;
                if (oldChild == lastChild)
                    _lastChild = newChild;
                return oldChild;
            }
            Node appendChild(Node newChild)
            {
                if (newChild.ownerDocument == ownerDocument)
                    throw new DOMException(ExceptionCode.WRONG_DOCUMENT);
                if (isSameNode(newChild) || newChild.isAncestor(Node.getWrapperOf(this)))
                    throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
                newChild.parentNode.removeChild(newChild);
                newChild.unwrap._parentNode = Node.getWrapperOf(this);
                if (lastChild)
                {
                    newChild.unwrap._previousSibling = lastChild;
                    lastChild.unwrap._nextSibling = newChild;
                }
                else
                    _firstChild = newChild;
                _lastChild = newChild;
                return newChild;
            }
            
            Node cloneNode(bool deep) const;
            void normalize();
            
            bool isSupported(string feature, string version_) const;
            
            DocumentPosition compareDocumentPosition(Node other);
            StringType lookupPrefix(StringType namespaceUri);
            bool isDefaultNamespace(StringType prefix);
            bool isEqualNode(Node arg);
            Object getFeature(string feature, string version_);
            
            UserData setUserData(string key, UserData data, UserDataHandler handler)
            {
                userData[key] = data;
                if (handler)
                    userDataHandlers[key] = handler;
                return data;
            }
            UserData getUserData(string key)
            {
                if (key in userData)
                    return userData[key];
                return Variant(null);
            }
        }
        // REQUIRED BY THE STANDARD; SHOULD NOT BE OVERRIDDEN
        public
        {
            @property auto childNodes()
            {
                struct NodeList
                {
                    Node parent;
                    Node item(size_t index)
                    {
                        auto result = parent.firstChild;
                        for (size_t i = 0; i < index && !result.isNull; i++)
                        {
                            result = result.nextSibling;
                        }
                        return result;
                    }
                    @property size_t length()
                    {
                        auto child = parent.firstChild;
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
                return NodeList(Node.getWrapperOf(this));
            }
            @property inout(Node) firstChild() inout { return _firstChild; }
            @property inout(Node) lastChild() inout { return _lastChild; }
            @property inout(Node) nextSibling() inout { return _nextSibling; }
            const Document ownerDocument;
            @property inout(Node) parentNode() inout { return _parentNode; }
            @property inout(Node) previousSibling() inout { return _previousSibling; }
            
            bool hasChildNodes() const
            {
                return !firstChild.isNull;
            }
            bool isSameNode(in Node other) const
            {
                return Node.getWrapperOf(this) == other;
            }
            Node removeChild(Node oldChild)
            {
                if (!isSameNode(oldChild.parentNode))
                    throw new DOMException(ExceptionCode.NOT_FOUND);
                
                if (oldChild == firstChild)
                    _firstChild = oldChild.nextSibling;
                else
                    oldChild.previousSibling.unwrap._nextSibling = oldChild.nextSibling;
                    
                if (oldChild == lastChild)
                    _lastChild = oldChild.previousSibling;
                else
                    oldChild.nextSibling.unwrap._previousSibling = oldChild.previousSibling;
                    
                oldChild.unwrap._parentNode = Node.Null;
                return oldChild;
            }
        }
        private Node _parentNode, _previousSibling, _nextSibling, _firstChild, _lastChild;
        private NamedNodeMap _attributes;
        private UserData[string] userData;
        private UserDataHandler[string] userDataHandlers;
        
        // NOT REQUIRED BY THE STANDARD; SHOULD NOT BE OVERRIDDEN
        public
        {
            void remove()
            {
                if (_parentNode)
                    parentNode.removeChild(Node.getWrapperOf(this));
            }
            bool isAncestor(in Node other)
            {
                for (auto child = firstChild; !child.isNull; child = child.nextSibling)
                {
                    if (child.isSameNode(other))
                        return true;
                    if (child.isAncestor(other))
                        return true;
                }
                return false;
            }
        }
    }

    @PolymorphicWrapper("Attr")
    struct _Attr
    {
        mixin DerivedOf!_Node;
        
        // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
        public
        {
            @property auto name() const { return _name; }
            @property auto specified() const { return _specified; }
            @property auto ownerElement() const { return _ownerElement; }
            @property auto schemaTypeInfo() const { return _schemaTypeInfo; }
            @property auto isId() const { return _isId; }
            
            @property StringType value()
            {
                StringType result = [];
                Node child = firstChild;
                while (child)
                {
                    result ~= child.textContent;
                    child = child.nextSibling;
                }
                return result;
            }
            @property void value(StringType newValue)
            {
                Node child = firstChild;
                while (child)
                {
                    auto nextChild = child.nextSibling;
                    child.remove();
                    child = nextChild;
                }
                _lastChild = ownerDocument.createTextNode(newValue);
                _firstChild = _lastChild;
            }
        }
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public
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
            @property auto nodeValue() { return value; }
            @property void nodeValue(StringType newValue) { value = newValue; }
            @property auto prefix() const { return name[0.._prefix_end]; }
            @property void prefix(StringType newPrefix)
            {
                _name = newPrefix ~ ':' ~ localName;
                _prefix_end = newPrefix.length;
            }
            @property auto textContent() { return value; }
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

    @PolymorphicWrapper("CharacterData")
    struct _CharacterData
    {
        mixin DerivedOf!_Node;
        mixin HasDerived!(_Comment, _Text);
        
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
        public
        {
            @property auto nodeValue() const { return data; }
            @property void nodeValue(StringType newValue) { data = newValue; }
            @property auto textContent() const { return data; }
            @property void textContent(StringType newValue) { data = newValue; }
            
            Node insertBefore(Node newChild,  Node refChild)
            {
                throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
            }
            Node replaceChild(Node newChild,  Node oldChild)
            {
                throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
            }
            Node appendChild(Node newChild)
            {
                throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
            }
        }
    }

    @PolymorphicWrapper("Comment")
    struct _Comment
    {
        mixin DerivedOf!_CharacterData;
    }

    @PolymorphicWrapper("Text")
    class _Text
    {
        mixin DerivedOf!_CharacterData;
        mixin HasDerived!CDATASection;
        
        // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
        public
        {
            @property auto isElementContentWhitespace() const { return false; } // <-- TODO!
            @property StringType wholeText() const { return []; }
            Text replaceWholeText(StringType newContent) { return Text.Null; } // <-- TODO!
            Text splitText(size_t offset)
            {
                if (offset > length)
                    throw new DOMException(ExceptionCode.INDEX_SIZE);
                    
                data = data[0..offset];
                Text newNode = ownerDocument.createTextNode(data[offset..$]);
                if (parentNode)
                {
                    newNode.unwrap._parentNode = parentNode;
                    newNode.unwrap._previousSibling = Node.getWrapperOf(this);
                    newNode.unwrap._nextSibling = nextSibling;
                    nextSibling.unwrap._previousSibling = newNode;
                    _nextSibling = newNode;
                }
                return newNode;
            }
        }
    }

    @PolymorphicWrapper("CDATASection")
    struct _CDATASection
    {
        mixin DerivedOf!_Text;
    }

    @PolymorphicWrapper("ProcessingInstruction")
    struct _ProcessingInstruction
    {
        mixin DerivedOf!_Node;
        
        // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
        public
        {
            const StringType target;
            StringType data;
        }
    }

    @PolymorphicWrapper("EntityReference")
    struct _EntityReference
    {
        mixin DerivedOf!_Node;
    }

    @PolymorphicWrapper("Entity")
    struct _Entity
    {
        mixin DerivedOf!_Node;
        
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

    @PolymorphicWrapper("Notation")
    struct _Notation
    {
        mixin DerivedOf!_Node;
        
        // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
        public
        {
            const StringType publicId;
            const StringType systemId;
        }
    }

    @PolymorphicWrapper("DocumentType")
    struct _DocumentType
    {
        mixin DerivedOf!_Node;
        
        // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
        public
        {
            const StringType name;
            const NamedNodeMap entities;
            const StringType publicId;
            const StringType systemId;
            const StringType internalSubset;
        }
    }

    @PolymorphicWrapper("Element")
    struct _Element
    {
        mixin DerivedOf!_Node;
        
        // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
        public
        {
            @property auto tagName() const { return _name; }
            @property auto schemaTypeInfo() const { return _schemaTypeInfo; }
            
            StringType getAttribute(StringType name) const
            {
                return _attributes.getNamedItem(name).nodeValue;
            }
            StringType getAttributeNS(StringType namespaceUri,  StringType localName) const
            {
                return _attributes.getNamedItemNS(namespaceUri, localName).nodeValue;
            }
            Attr getAttributeNode(StringType name) const
            {
                return cast(Attr)_attributes.getNamedItem(name);
            }
            Attr getAttributeNodeNS(StringType namespaceUri,  StringType localName) const
            {
                return cast(Attr)_attributes.getNamedItemNS(namespaceUri, localName);
            }
            
            void setAttribute(StringType name,  StringType value)
            {
                auto attr = ownerDocument.createAttribute(name);
                attr.value = value;
                _attributes.setNamedItem(cast(Node)attr);
            }
            void setAttributeNS(StringType namespaceUri,  StringType qualifiedName,  StringType value)
            {
                auto attr = ownerDocument.createAttributeNS(namespaceUri, qualifiedName);
                attr.value = value;
                _attributes.setNamedItemNS(cast(Node)attr);
            }
            Attr setAttributeNode(Attr newAttr)
            {
                return cast(Attr)_attributes.setNamedItem(cast(Node)newAttr);
            }
            Attr setAttributeNodeNS(Attr newAttr)
            {
                return cast(Attr)_attributes.setNamedItemNS(cast(Node)newAttr);
            }
            
            void removeAttribute(StringType name)
            {
                _attributes.removeNamedItem(name);
            }
            void removeAttributeNS(StringType namespaceUri,  StringType localName)
            {
                _attributes.removeNamedItemNS(namespaceUri, localName);
            }
            Attr removeAttributeNode(Attr oldAttr);
            
            NodeList getElementsByTagName(StringType name) const;
            NodeList getElementsByTagNameNS(StringType namespaceUri,  StringType localName) const;
            
            bool hasAttribute(StringType name) const;
            bool hasAttributeNS(StringType namespaceUri,  StringType localName) const;
            
            void setIdAttribute(StringType name,  bool isId);
            void setIdAttributeNS(StringType namespaceUri,  StringType localName,  bool isId);
            void setIdAttributeNode(Attr idAttr,  bool isId);
        }
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public
        {
            @property auto localName() { return tagName[_prefix_end..$]; }
            @property auto nodeName() { return tagName; }
            @property auto prefix() { return tagName[0.._prefix_end]; }
            @property void prefix(StringType newPrefix)
            {
                _name = newPrefix ~ localName;
                _prefix_end = newPrefix.length;
            }
            bool hasAttributes() const
            {
                return !_attributes.isNull && _attributes.length > 0;
            }
        }
        private
        {
            StringType _name;
            size_t _prefix_end;
            TypeInfo _schemaTypeInfo;
            NamedNodeMap _attributes;
        }
    }

    @PolymorphicWrapper("Document")
    struct _Document
    {
        mixin DerivedOf!_Node;
        
        // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
        public
        {
            const DocumentType doctype;
            const DOMImplementation implementation;
            const Element documentElement;
            
            Element createElement(StringType tagName) { return assertAbstract!Element; }
            Element createElementNS(StringType namespaceUri, StringType qualifiedName) const { return assertAbstract!Element; }
            Text createTextNode(StringType text) const { return assertAbstract!Text; }
            Comment createComment(StringType text) const { return assertAbstract!Comment; }
            CDATASection createCDataSection(StringType text) const { return assertAbstract!CDATASection; }
            ProcessingInstruction createProcessingInstruction(StringType target, StringType data) const { return assertAbstract!ProcessingInstruction; }
            Attr createAttribute(StringType name) const { return assertAbstract!Attr; }
            Attr createAttributeNS(StringType namespaceUri, StringType qualifiedName) const { return assertAbstract!Attr; }
            EntityReference createEntityReference(StringType name) const { return assertAbstract!EntityReference; }
            
            NodeList getElementsByTagName(StringType tagName) { return assertAbstract!NodeList; }
            NodeList getElementsByTagNameNS(StringType namespaceUri, StringType tagName) { return assertAbstract!NodeList; }
            Node getElementById(StringType elementId) { return assertAbstract!Node; }
            
            Node importNode(Node node, bool deep) { return assertAbstract!Node; }
            Node adoptNode(Node source) { return assertAbstract!Node; }
            Node renameNode(Node n, StringType namespaceUri, StringType qualifiedName) { return assertAbstract!Node; }
            
            const StringType inputEncoding;
            const StringType xmlEncoding;
            const DOMConfiguration domConfig;
            
            @property bool xmlStandalone() { return assertAbstract!bool; }
            @property void xmlStandalone(bool val) { return assertAbstract; }
            @property StringType xmlVersion() { return assertAbstract!StringType; }
            @property void xmlVersion(StringType val) { return assertAbstract; }
            
            bool strictErrorChecking = true;
            StringType documentURI;
            
            void normalizeDocument();
        }
    }
    
    @PolymorphicWrapper("DocumentFragment")
    struct _DocumentFragment
    {
        mixin DerivedOf!_Node;
    }
    
    @PolymorphicWrapper("NodeList")
    struct _NodeList
    {
        mixin BaseClass;
        
        // REQUIRED BY THE STANDARD
        public
        {
            ulong length() { return assertAbstract!ulong; }
            Node item(ulong index) { return assertAbstract!Node; }
        }
    }
    
    @PolymorphicWrapper("NamedNodeMap")
    struct _NamedNodeMap
    {
        mixin BaseClass;
        
        // REQUIRED BY THE STANDARD
        public
        {
            ulong length() const { return assertAbstract!ulong; }
            Node item(ulong index) const { return assertAbstract!Node; }
            
            Node getNamedItem(StringType name) const { return assertAbstract!Node; }
            Node setNamedItem(Node arg) { return assertAbstract!Node; }
            Node removeNamedItem(StringType name) { return assertAbstract!Node; }
            
            Node getNamedItemNS(StringType namespaceUri, StringType localName) const { return assertAbstract!Node; }
            Node setNamedItemNS(Node arg) { return assertAbstract!Node; }
            Node removeNamedItemNS(StringType namespaceUri, StringType localName) { return assertAbstract!Node; }
        }
    }
    
    @PolymorphicWrapper("DOMImplementation")
    struct _DOMImplementation
    {
        mixin BaseClass;
    }
    
    @PolymorphicWrapper("DOMConfiguration")
    struct _DOMConfiguration
    {
        mixin BaseClass;
    }
}

mixin template InjectDOM(StringType)
{
    alias Node = DOM!StringType.Node;
    alias Attr = DOM!StringType.Attr;
    alias Element = DOM!StringType.Element;
    alias CharacterData = DOM!StringType.CharacterData;
    alias Text = DOM!StringType.Text;
    alias Comment = DOM!StringType.Comment;
    alias CDATASection = DOM!StringType.CDATASection;
    alias ProcessingInstruction = DOM!StringType.ProcessingInstruction;
    alias Notation = DOM!StringType.Notation;
    alias Entity = DOM!StringType.Entity;
    alias EntityReference = DOM!StringType.EntityReference;
    alias Document = DOM!StringType.Document;
    alias DocumentFragment = DOM!StringType.DocumentFragment;
    alias DocumentType = DOM!StringType.DocumentType;
}

unittest
{
    mixin InjectDOM!string;
}
