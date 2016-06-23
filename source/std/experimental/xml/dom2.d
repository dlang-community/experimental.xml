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

module std.experimental.xml.dom2;

import std.conv: to;

struct RefCounted(T, Alloc, bool _userVisible = false)
    if (is(T == class))
{
    import std.experimental.allocator.building_blocks.affix_allocator;
    import std.experimental.allocator;
    import std.traits: BaseClassesTuple, Unqual, CopyTypeQualifiers;
    import std.typecons: Rebindable;
    
    static shared AffixAllocator!(Alloc, size_t) _p_alloc;
    static this() @nogc
    {
        _p_alloc = _p_alloc.instance;
    }

    private Rebindable!T _p_data;
    
    static if (!is(Unqual!T == Object))
    {
        static if (is(BaseClassesTuple!(Unqual!T)[0]))
            alias SuperType = RefCounted!(CopyTypeQualifiers!(T, BaseClassesTuple!(Unqual!T)[0]), Alloc, _userVisible);
        else
            alias SuperType = RefCounted!(CopyTypeQualifiers!(T, Object), Alloc, _userVisible);
            
        SuperType superType() @nogc
        {
            return SuperType(_p_data);
        }
        alias superType this;
    }
    
    private void[] _p_dataBlock() const @nogc
    {
        void[] result = (cast(ubyte*)cast(void*)_p_data)[0..T.sizeof];
        return result;
    }
    private void _p_incr() @nogc
    {
        if (_p_data)
        {
            _p_alloc.prefix(_p_dataBlock)++;
            static if (_userVisible && is(typeof(T.incrVisibleRefCount)))
                _p_data.incrVisibleRefCount;
        }
    }
    private void _p_decr() @nogc
    {
        if (_p_data)
        {
            static if (_userVisible && is(typeof(T.decrVisibleRefCount)))
                _p_data.decrVisibleRefCount;
            if (--_p_alloc.prefix(_p_dataBlock) == 0)
                _p_alloc.deallocate(_p_dataBlock);
        }
    }
    
    this(typeof(null)) @nogc
    {
        _p_data = null;
    }
    this(T payload) @nogc
    {
        _p_data = payload;
        _p_incr;
    }
    this(this) @nogc
    {
        _p_incr;
    }
    ~this() @nogc
    {
        _p_decr;
    }
    
    bool opEquals(typeof(null) other) const @nogc
    {
        return _p_data is null;
    }
    bool opEquals(U, bool visibility)(const auto ref RefCounted!(U, Alloc, visibility) other) const @nogc
    {
        return _p_data is other._p_data;
    }
    bool opCast(T: bool)() const @nogc
    {
        return (_p_data)?true:false;
    }
    
    void opAssign(typeof(null) other) @nogc
    {
        _p_decr;
        _p_data = null;
    }
    void opAssign(U, bool visibility)(auto ref RefCounted!(U, Alloc, visibility) other) @nogc
    {
        _p_decr;
        _p_data = other._p_data;
        _p_incr;
    }
    
    static RefCounted emplace(Args...)(auto ref Args args) @nogc
    {
        RefCounted result;
        result._p_data = _p_alloc.make!T(args);
        
        import core.memory;
        auto block = result._p_dataBlock;
        GC.addRange(block.ptr, block.length, T.classinfo);
        _p_alloc.prefix(result._p_dataBlock) = 1;
        return result;
    }
    static RefCounted Null() @nogc
    {
        RefCounted result;
        result._p_data = null;
        return result;
    }
    
    alias UserVisible = RefCounted!(T, Alloc, true);
    UserVisible userVisible() @nogc
    {
        return UserVisible(_p_data);
    }
    alias LibInternal = RefCounted!(T, Alloc, false);
    LibInternal libInternal() @nogc
    {
        return LibInternal(_p_data);
    }
    
    RefCounted!(U, Alloc, _userVisible) downCast(RC: RefCounted!(U, Alloc, _userVisible), U)() @nogc
    {
        return RefCounted!(U, Alloc, _userVisible)(cast(U)_p_data);
    }
    
    @property auto opDispatch(string name, Arg)(Arg arg)
    {
        mixin("return _p_data." ~ name ~ " = arg;");
    }
    auto opDispatch(string name, Args...)(Args args)
    {
        static if (Args.length > 0)
            mixin("return _p_data." ~ name ~ "(args);");
        else
            mixin("return _p_data." ~ name ~ ";");
    }
}

import std.typecons: Tuple;
import std.variant: Variant;

alias UserData = Variant;

enum NodeType: ushort
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
enum DocumentPosition: ushort
{
    DISCONNECTED,
    PRECEDING,
    FOLLOWING,
    CONTAINS,
    CONTAINED_BY,
    IMPLEMENTATION_SPECIFIC,
}
enum UserDataOperation: ushort
{
    NODE_CLONED,
    NODE_IMPORTED,
    NODE_DELETED,
    NODE_RENAMED,
    NODE_ADOPTED,
}

enum ExceptionCode: ushort
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

template DOM(StringType, Alloc = typeof(null))
{
    // We are using a custom allocator and reference counting
    static if (!is(Alloc == typeof(null)))
    {
        // Types to be used in public APIs and user code; they keep the DOM trees alive
        alias Node = RefCounted!(_Node, Alloc, true);
        alias Attr = RefCounted!(_Attr, Alloc, true);
        alias CharacterData = RefCounted!(_CharacterData, Alloc, true);
        alias Comment = RefCounted!(_Comment, Alloc, true);
        alias Text = RefCounted!(_Text, Alloc, true);
        alias CDATASection = RefCounted!(_CDATASection, Alloc, true);
        alias ProcessingInstruction = RefCounted!(_ProcessingInstruction, Alloc, true);
        alias EntityReference = RefCounted!(_EntityReference, Alloc, true);
        alias Entity = RefCounted!(_Entity, Alloc, true);
        alias Notation = RefCounted!(_Notation, Alloc, true);
        alias DocumentType = RefCounted!(_DocumentType, Alloc, true);
        alias Element = RefCounted!(_Element, Alloc, true);
        alias Document = RefCounted!(_Document, Alloc, true);
        alias DocumentFragment = RefCounted!(_DocumentFragment, Alloc, true);
        
        // Types to be used internally; they do not keep the DOM alive and are needed to avoid
        // circular references that prevent deallocation
        alias WeakNode = RefCounted!(_Node, Alloc);
        alias WeakAttr = RefCounted!(_Attr, Alloc);
        alias WeakCharacterData = RefCounted!(_CharacterData, Alloc);
        alias WeakComment = RefCounted!(_Comment, Alloc);
        alias WeakText = RefCounted!(_Text, Alloc);
        alias WeakCDATASection = RefCounted!(_CDATASection, Alloc);
        alias WeakProcessingInstruction = RefCounted!(_ProcessingInstruction, Alloc);
        alias WeakEntityReference = RefCounted!(_EntityReference, Alloc);
        alias WeakEntity = RefCounted!(_Entity, Alloc);
        alias WeakNotation = RefCounted!(_Notation, Alloc);
        alias WeakDocumentType = RefCounted!(_DocumentType, Alloc);
        alias WeakElement = RefCounted!(_Element, Alloc);
        alias WeakDocument = RefCounted!(_Document, Alloc);
        alias WeakDocumentFragment = RefCounted!(_DocumentFragment, Alloc);
        
        // others
        alias NodeList = RefCounted!(_NodeList, Alloc);
        alias NamedNodeMap = RefCounted!(_NamedNodeMap, Alloc);
        alias NamedNodeMapImpl_ElementAttributes = RefCounted!(_NamedNodeMapImpl_ElementAttributes, Alloc);
    }
    // we are using the gc
    else
    {
        alias Node = _Node;
        alias Attr = _Attr;
        alias CharacterData = _CharacterData;
        alias Comment = _Comment;
        alias Text = _Text;
        alias CDATASection = _CDATASection;
        alias ProcessingInstruction = _ProcessingInstruction;
        alias EntityReference = _EntityReference;
        alias Entity = _Entity;
        alias Notation = _Notation;
        alias DocumentType = _DocumentType;
        alias Element = _Element;
        alias Document = _Document;
        alias DocumentFragment = _DocumentFragment;
        
        alias WeakNode = _Node;
        alias WeakAttr = _Attr;
        alias WeakCharacterData = _CharacterData;
        alias WeakComment = _Comment;
        alias WeakText = _Text;
        alias WeakCDATASection = _CDATASection;
        alias WeakProcessingInstruction = _ProcessingInstruction;
        alias WeakEntityReference = _EntityReference;
        alias WeakEntity = _Entity;
        alias WeakNotation = _Notation;
        alias WeakDocumentType = _DocumentType;
        alias WeakElement = _Element;
        alias WeakDocument = _Document;
        alias WeakDocumentFragment = _DocumentFragment;
        
        alias NodeList = _NodeList;
        alias NamedNodeMap = _NamedNodeMap;
        alias NamedNodeMapImpl_ElementAttributes = _NamedNodeMapImpl_ElementAttributes;
        
        T userVisible(T)(auto ref T val) { return val; }
        T libInternal(T)(auto ref T val) { return val; }
    }
    
    alias UserDataHandler = void delegate(UserDataOperation, string, UserData, Node, Node);
    
    abstract class _Node
    {
        // REQUIRED BY THE STANDARD; TO BE IMPLEMENTED BY SUBCLASSES
        public abstract
        {
            @property StringType    namespaceUri()    const @nogc;
            @property StringType    nodeName()        const @nogc;
            @property NodeType      nodeType()        const @nogc;
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
            @property NamedNodeMap attributes() { return to!NamedNodeMap(null); }
            StringType localName() const @nogc { return null; }
            @property StringType nodeValue() { return null; }
            @property void nodeValue(StringType newValue) {}
            @property StringType prefix() const @nogc { return null; }
            @property void prefix(StringType newValue) {}
            @property StringType baseUri() { return parentNode.baseUri(); }
            
            bool hasAttributes() { return false; }
            
            @property StringType textContent()
            {
                StringType result = [];
                for (Node child = firstChild; child != null; child = child.nextSibling)
                    if (child.nodeType != NodeType.PROCESSING_INSTRUCTION && child.nodeType != NodeType.COMMENT)
                        result ~= child.textContent;
                return result;
            }
            @property void textContent(StringType newValue)
            {
                while (firstChild)
                    removeChild(firstChild);
                appendChild(ownerDocument.createTextNode(newValue));
            }
            
            Node insertBefore(Node newChild, Node refChild)
            {
                if (newChild.ownerDocument != ownerDocument)
                    throw new DOMException(ExceptionCode.WRONG_DOCUMENT);
                if (isSameNode(newChild) || newChild.isAncestor(Node(this)) || newChild == refChild)
                    throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
                if (!isSameNode(refChild.parentNode))
                    throw new DOMException(ExceptionCode.NOT_FOUND);
                if (newChild.parentNode != null)
                    newChild.parentNode.removeChild(newChild);
                newChild._parentNode = Node(this);
                if (refChild.previousSibling)
                {
                    refChild.previousSibling._nextSibling = newChild;
                    newChild._previousSibling = refChild.previousSibling;
                }
                refChild._previousSibling = newChild;
                newChild._nextSibling = refChild;
                if (firstChild == refChild)
                    _firstChild = newChild;
                return newChild;
            }
            Node replaceChild(Node newChild, Node oldChild)
            {
                if (newChild.ownerDocument != ownerDocument)
                    throw new DOMException(ExceptionCode.WRONG_DOCUMENT);
                if (isSameNode(newChild) || newChild.isAncestor(Node(this)))
                    throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
                if (!isSameNode(oldChild.parentNode))
                    throw new DOMException(ExceptionCode.NOT_FOUND);
                if (newChild.parentNode != null)
                    newChild.parentNode.removeChild(newChild);
                newChild._parentNode = Node(this);
                oldChild._parentNode = null;
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
                if (isSameNode(newChild) || newChild.isAncestor(Node(this)))
                    throw new DOMException(ExceptionCode.HIERARCHY_REQUEST);
                if (newChild.parentNode != null)
                    newChild.parentNode.removeChild(newChild);
                newChild._parentNode = Node(this);
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
            
            Node cloneNode(bool deep) @nogc { return Node.Null; }
            void normalize() {}
            
            bool isSupported(string feature, string version_) const { return false; }
            
            DocumentPosition compareDocumentPosition(Node other) { return DocumentPosition.PRECEDING; }
            StringType lookupPrefix(StringType namespaceUri) { return null; }
            bool isDefaultNamespace(StringType prefix) { return false; }
            bool isEqualNode(Node arg) { return false; }
            Object getFeature(string feature, string version_) { return null; }
            
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
        public final
        {
            @property NodeList childNodes()
            {
                class _ChildNodeList: _NodeList
                {
                    private Node parent;
                    override Node item(size_t index)
                    {
                        auto result = parent.firstChild;
                        for (size_t i = 0; i < index && result != null; i++)
                        {
                            result = result.nextSibling;
                        }
                        return result;
                    }
                    override @property size_t length()
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
                alias ChildNodeList = RefCounted!(_ChildNodeList, Alloc);
                auto cnl = ChildNodeList.emplace();
                cnl.parent = Node(this);
                return cnl;
            }
            @property Node firstChild() { return _firstChild.userVisible; }
            @property Node lastChild() { return _lastChild.userVisible; }
            @property Node nextSibling() { return _nextSibling.userVisible; }
            @property Document ownerDocument() { return _ownerDocument.userVisible; }
            @property Node parentNode() { return _parentNode.userVisible; }
            @property Node previousSibling() { return _previousSibling.userVisible; }
            
            bool hasChildNodes() const @nogc
            {
                return _firstChild != null;
            }
            bool isSameNode(in Node other) @nogc
            {
                return Node(this) == other;
            }
            Node removeChild(Node oldChild)
            {
                if (!isSameNode(oldChild.parentNode))
                    throw new DOMException(ExceptionCode.NOT_FOUND);
                
                if (oldChild == firstChild)
                    _firstChild = oldChild.nextSibling;
                else
                    oldChild.previousSibling._nextSibling = oldChild.nextSibling;
                    
                if (oldChild == lastChild)
                    _lastChild = oldChild.previousSibling;
                else
                    oldChild.nextSibling._previousSibling = oldChild.previousSibling;
                    
                oldChild._parentNode = null;
                return oldChild;
            }
        }
        private WeakNode _parentNode, _previousSibling, _nextSibling, _firstChild, _lastChild;
        private WeakDocument _ownerDocument;
        private UserData[string] userData;
        private UserDataHandler[string] userDataHandlers;
        
        // NOT REQUIRED BY THE STANDARD; SHOULD NOT BE OVERRIDDEN
        public final
        {
            void removeFromParent()
            {
                if (_parentNode)
                    parentNode.removeChild(Node(this));
            }
            bool isAncestor(in Node other)
            {
                for (auto child = firstChild; child != null; child = child.nextSibling)
                {
                    if (child.isSameNode(other))
                        return true;
                    if (child.isAncestor(other))
                        return true;
                }
                return false;
            }
        }
        
        // internal reference counting code
        private
        {
            size_t refCount;
            final void incrVisibleRefCount(size_t count = 1) @nogc
            {
                refCount += count;
                WeakNode parent = getParent;
                if (parent != null)
                    parent.incrVisibleRefCount(count);
            }
            final void decrVisibleRefCount(size_t count = 1) @nogc
            {
                refCount -= count;
                WeakNode parent = getParent();
                if (parent != null)
                    parent.decrVisibleRefCount(count);
                else if (refCount == 0)
                    destroyInternalReferences;
            }
            final void detachFromParent() @nogc
            {
                WeakNode parent = getParent;
                if (parent != null)
                    parent.decrVisibleRefCount(refCount);
            }
            final void attachToParent() @nogc
            {
                WeakNode parent = getParent;
                if (parent != null)
                    parent.incrVisibleRefCount(refCount);
            }
            WeakNode getParent() @nogc
            {
                return _parentNode;
            }
            void destroyInternalReferences()
            {
                // should contain code to delete all internal references,
                // so that RefCounted can reclaim memory.
            }
        }
    }
    
    class _Attr: _Node
    {
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
                    child.removeFromParent;
                    child = nextChild;
                }
                _lastChild = ownerDocument.createTextNode(newValue);
                _firstChild = _lastChild;
            }
        }
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public override
        {
            @property StringType localName() const @nogc
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
            @property StringType prefix() const @nogc { return name[0.._prefix_end]; }
            @property void prefix(StringType newPrefix)
            {
                _name = newPrefix ~ ':' ~ localName;
                _prefix_end = newPrefix.length;
            }
            @property StringType textContent() { return value; }
            @property void textContent(StringType newContent) { value = newContent; }
            
            @property StringType namespaceUri() const @nogc { return _namespaceUri; }
        }
        private
        {
            StringType _name, _namespaceUri;
            size_t _prefix_end;
            bool _specified, _isId;
            WeakElement _ownerElement;
            TypeInfo _schemaTypeInfo;
        }
    }

    class _CharacterData: _Node
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
            
            @property StringType namespaceUri() const @nogc { return null;}
        }
    }

    class _Comment: _CharacterData
    {
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public override
        {
            @property NodeType nodeType() const @nogc { return NodeType.COMMENT; }
            @property StringType nodeName() const @nogc { return "#comment"; }
        }
    }

    class _Text: _CharacterData
    {
        // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
        public
        {
            @property auto isElementContentWhitespace() const { return false; } // <-- TODO!
            @property StringType wholeText() const { return []; }
            Text replaceWholeText(StringType newContent) { return Text(); } // <-- TODO!
            Text splitText(size_t offset)
            {
                if (offset > length)
                    throw new DOMException(ExceptionCode.INDEX_SIZE);
                    
                data = data[0..offset];
                Text newNode = ownerDocument.createTextNode(data[offset..$]);
                if (parentNode)
                {
                    newNode._parentNode = parentNode;
                    newNode._previousSibling = Node(this);
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
            @property NodeType nodeType() const @nogc { return NodeType.TEXT; }
            @property StringType nodeName() const @nogc { return "#text"; }
        }
    }

    class _CDATASection: _Text
    {
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public override
        {
            @property NodeType nodeType() const @nogc { return NodeType.CDATA_SECTION; }
            @property StringType nodeName() const @nogc { return "#cdata-section"; }
        }
    }

    class _ProcessingInstruction: _Node
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
            @property NodeType nodeType() const @nogc { return NodeType.PROCESSING_INSTRUCTION; }
            @property StringType nodeName() const @nogc { return target; }
            @property StringType namespaceUri() const @nogc { return null; }
        }
    }
    
    class _EntityReference: _Node
    {
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public override
        {
            @property NodeType nodeType() const @nogc { return NodeType.ENTITY_REFERENCE; }
            @property StringType nodeName() const @nogc { return null; }
        }
    }

    class _Entity: _Node
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
            @property NodeType nodeType() const @nogc { return NodeType.ENTITY; }
            @property StringType nodeName() const @nogc { return null; }
        }
    }

    class _Notation: _Node
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
            @property NodeType nodeType() const @nogc { return NodeType.NOTATION; }
            @property StringType nodeName() const @nogc { return null; }
        }
    }
    
    class _DocumentType: _Node
    {
        // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
        public
        {
            const StringType name;
            const NamedNodeMap entities;
            const StringType publicId;
            const StringType systemId;
            const StringType internalSubset;
        }
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public override
        {
            @property NodeType nodeType() const @nogc { return NodeType.DOCUMENT_TYPE; }
            @property StringType nodeName() const @nogc { return name; }
        }
    }

    class _Element: _Node
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
            Attr getAttributeNode(StringType name)
            {
                return _attributes.getNamedItem(name).downCast!Attr;
            }
            Attr getAttributeNodeNS(StringType namespaceUri,  StringType localName)
            {
                return _attributes.getNamedItemNS(namespaceUri, localName).downCast!Attr;
            }
            
            void setAttribute(StringType name,  StringType value)
            {
                auto attr = ownerDocument.createAttribute(name);
                attr.value = value;
                _attributes.setNamedItem(attr);
            }
            void setAttributeNS(StringType namespaceUri,  StringType qualifiedName,  StringType value)
            {
                auto attr = ownerDocument.createAttributeNS(namespaceUri, qualifiedName);
                attr.value = value;
                _attributes.setNamedItemNS(attr);
            }
            Attr setAttributeNode(Attr newAttr)
            {
                return _attributes.setNamedItem(newAttr).downCast!Attr;
            }
            Attr setAttributeNodeNS(Attr newAttr)
            {
                return _attributes.setNamedItemNS(newAttr).downCast!Attr;
            }
            
            void removeAttribute(StringType name)
            {
                _attributes.removeNamedItem(name);
            }
            void removeAttributeNS(StringType namespaceUri,  StringType localName)
            {
                _attributes.removeNamedItemNS(namespaceUri, localName);
            }
            Attr removeAttributeNode(Attr oldAttr) { return Attr.Null; }
            
            NodeList getElementsByTagName(StringType name) const { return NodeList.Null; }
            NodeList getElementsByTagNameNS(StringType namespaceUri,  StringType localName) const { return NodeList(); }
            
            bool hasAttribute(StringType name) const { return false; }
            bool hasAttributeNS(StringType namespaceUri,  StringType localName) const { return false; }
            
            void setIdAttribute(StringType name,  bool isId) {}
            void setIdAttributeNS(StringType namespaceUri,  StringType localName,  bool isId) {}
            void setIdAttributeNode(Attr idAttr,  bool isId) {}
        }
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public override
        {
            @property StringType localName() const @nogc
            {
                if (_prefix_end > 0)
                    return tagName[_prefix_end..$];
                else
                    return null;
            }
            @property StringType nodeName() const @nogc { return tagName; }
            @property StringType prefix() const @nogc { return tagName[0.._prefix_end]; }
            @property void prefix(StringType newPrefix)
            {
                _name = newPrefix ~ localName;
                _prefix_end = newPrefix.length;
            }
            bool hasAttributes() @nogc
            {
                return _attributes != null && _attributes.length > 0;
            }
            @property StringType baseUri()
            {
                auto base = getAttributeNS("http://www.w3.org/XML/1998/namespace", "base");
                if (base != null)
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
            NamedNodeMap _attributes;
            StringType _namespaceUri;
        }
        package(std) this()
        {
            _attributes = NamedNodeMapImpl_ElementAttributes.emplace();
        }
    }

    class _Document: _Node
    {
        // REQUIRED BY THE STANDARD; SPECIFIC TO THIS CLASS
        public
        {
            const DocumentType doctype;
            const DOMImplementation implementation;
            const Element documentElement;
            
            Element createElement(StringType tagName) @nogc
            {
                auto result = Element.emplace();
                result._name = tagName;
                result._ownerDocument = Document(this);
                return result;
            }
            Element createElementNS(StringType namespaceUri, StringType qualifiedName) @nogc
            {
                import std.experimental.xml.faststrings: fastIndexOf;
                
                auto result = Element.emplace();
                result._namespaceUri = namespaceUri;
                result._name = qualifiedName;
                auto pos = fastIndexOf(qualifiedName, ':');
                result._prefix_end = pos >= 0 ? pos : 0;
                result._ownerDocument = Document(this);
                return result;
            }
            Text createTextNode(StringType text) const @nogc
            {
                auto result = Text.emplace();
                result.data = text;
                return result;
            }
            Comment createComment(StringType text) const @nogc
            {
                auto result = Comment.emplace();
                result.data = text;
                return result;
            }
            CDATASection createCDataSection(StringType text) const @nogc
            {
                auto result = CDATASection.emplace();
                result.data = text;
                return result;
            }
            ProcessingInstruction createProcessingInstruction(StringType target, StringType data) const @nogc
            {
                auto result = ProcessingInstruction.emplace();
                result.target = target;
                result.data = data;
                return result;
            }
            Attr createAttribute(StringType name) @nogc
            {
                auto result = Attr.emplace();
                result._name = name;
                result._ownerDocument = Document(this);
                return result;
            }
            Attr createAttributeNS(StringType namespaceUri, StringType qualifiedName) @nogc
            {
                import std.experimental.xml.faststrings: fastIndexOf;
                
                auto result = Attr.emplace();
                result._namespaceUri = namespaceUri;
                result._name = qualifiedName;
                auto pos = fastIndexOf(qualifiedName, ':');
                result._prefix_end = pos >= 0 ? pos : 0;
                result._ownerDocument = Document(this);
                return result;
            }
            EntityReference createEntityReference(StringType name) const { return EntityReference(); }
            
            NodeList getElementsByTagName(StringType tagName) { return NodeList(); }
            NodeList getElementsByTagNameNS(StringType namespaceUri, StringType tagName) { return NodeList(); }
            Node getElementById(StringType elementId) { return Node(); }
            
            Node importNode(Node node, bool deep) { return Node(); }
            Node adoptNode(Node source) { return Node(); }
            Node renameNode(Node n, StringType namespaceUri, StringType qualifiedName) { return Node(); }
            
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
    
    class _DocumentFragment: _Node
    {
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public override
        {
            @property NodeType nodeType() const @nogc { return NodeType.DOCUMENT_FRAGMENT; }
            @property StringType nodeName() const @nogc { return "#document-fragment"; }
        }
    }
    
    abstract class _NodeList
    {
        // REQUIRED BY THE STANDARD
        public
        {
            abstract ulong length();
            abstract Node item(ulong index);
        }
    }
    
    abstract class _NamedNodeMap
    {
        // REQUIRED BY THE STANDARD
        public
        {
            abstract ulong length() const @nogc;
            abstract Node item(ulong index);
            
            abstract Node getNamedItem(StringType name) @nogc;
            abstract Node setNamedItem(Node arg);
            abstract Node removeNamedItem(StringType name);
            
            abstract Node getNamedItemNS(StringType namespaceUri, StringType localName) @nogc;
            abstract Node setNamedItemNS(Node arg);
            abstract Node removeNamedItemNS(StringType namespaceUri, StringType localName);
        }
    }
    
    private class _NamedNodeMapImpl_ElementAttributes: _NamedNodeMap
    {
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public override
        {
            ulong length() const @nogc
            {
                return attrs.length;
            }
            Node item(ulong index)
            {
                if (index < attrs.keys.length)
                    return *(attrs.keys[index] in attrs);
                else
                    return Node.Null;
            }
            
            Node getNamedItem(StringType name) @nogc
            {
                return getNamedItemNS(null, name);
            }
            Node setNamedItem(Node arg)
            {
                return setNamedItemNS(arg);
            }
            Node removeNamedItem(StringType name)
            {
                return removeNamedItemNS(null, name);
            }
            
            Node getNamedItemNS(StringType namespaceUri, StringType localName) @nogc
            {
                auto key = Key(namespaceUri, localName);
                if (key in attrs)
                    return *(key in attrs);
                else
                    return Attr.Null;
            }
            Node setNamedItemNS(Node arg)
            {
                Attr attr = arg.downCast!Attr;
                auto key = Key(attr.namespaceUri, attr.localName);
                auto oldAttr = (key in attrs) ? *(key in attrs) : Attr();
                attrs[key] = attr;
                return oldAttr;
            }
            Node removeNamedItemNS(StringType namespaceUri, StringType localName)
            {
                auto key = Key(namespaceUri, localName);
                if (key in attrs)
                {
                    auto result = attrs.get(key, Attr());
                    attrs.remove(key);
                    return result;
                }
                else
                    throw new DOMException(ExceptionCode.NOT_FOUND);
            }
        }
        private alias Key = Tuple!(StringType, "namespaceUri", StringType, "localName");
        private Attr[Key] attrs;
    }
    
    struct DOMImplementation
    {
    }
    
    struct DOMConfiguration
    {
    }
    
}

mixin template InjectDOM(StringType, Alloc = typeof(null), string prefix = "", string suffix = "")
{
    private mixin template InjectClass(string name, T)
    {
        mixin ("alias " ~ prefix ~ name ~ suffix ~ " = T;");
    }
    private alias _DOM = DOM!(StringType, Alloc);
    mixin InjectClass!("Node", _DOM.Node);
    mixin InjectClass!("Attr", _DOM.Attr);
    mixin InjectClass!("Element", _DOM.Element);
    mixin InjectClass!("CharacterData", _DOM.CharacterData);
    mixin InjectClass!("Text", _DOM.Text);
    mixin InjectClass!("Comment", _DOM.Comment);
    mixin InjectClass!("CDATASection", _DOM.CDATASection);
    mixin InjectClass!("ProcessingInstruction", _DOM.ProcessingInstruction);
    mixin InjectClass!("Notation", _DOM.Notation);
    mixin InjectClass!("Entity", _DOM.Entity);
    mixin InjectClass!("EntityReference", _DOM.EntityReference);
    mixin InjectClass!("Document", _DOM.Document);
    mixin InjectClass!("DocumentFragment", _DOM.DocumentFragment);
    mixin InjectClass!("DocumentType", _DOM.DocumentType);
}

unittest
{
    import std.experimental.allocator.mallocator;
    mixin InjectDOM!(string, Mallocator);
    auto document = Document.emplace();
    auto element = document.createElement("myElement");
    element.setAttribute("myAttribute", "myValue");
    assert(element.getAttribute("myAttribute") == "myValue");
    auto text = document.createTextNode("Some useful insight...");
    element.appendChild(text);
    assert(element.firstChild.textContent == "Some useful insight...");
}
