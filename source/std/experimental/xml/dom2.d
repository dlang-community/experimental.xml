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

import std.experimental.allocator.gc_allocator;

template DOM(StringType, alias Alloc = GCAllocator, bool advancedRefCouting = true)
{
    // custom wrapper to manage the lifetime of the DOM objects
    struct RefCounted(T, bool _userVisible = false)
        if (is(T == class))
    {
        import std.experimental.allocator.building_blocks.affix_allocator;
        import std.experimental.allocator;
        import std.traits: BaseClassesTuple, Unqual, CopyTypeQualifiers;
        import std.typecons: Rebindable;

        // get the correct allocator
        static if (is(Alloc == GCAllocator))
        {
            private static shared GCAllocator _p_alloc;
            static this()
            {
                _p_alloc = typeof(_p_alloc).instance;
            }
            private enum _p_rc = false;
        }
        else static if (is(typeof(Alloc) == GCAllocator))
        {
            private static alias _p_alloc = Alloc;
            private enum _p_rc = false;
        }
        else static if (is(Alloc))
        {
            private static shared AffixAllocator!(Alloc, size_t) _p_alloc;
            static this()
            {
                _p_alloc = typeof(_p_alloc).instance;
            }
            private enum _p_rc = true;
        }
        else
        {
            private static shared AffixAllocator!(typeof(Alloc), size_t) _p_alloc;
            static if (stateSize!(typeof(_p_alloc)))
                static this()
                {
                    _p_alloc = typeof(_p_alloc)(Alloc);
                }
            private enum _p_rc = false;
        }

        // the actual wrapped data
        private Rebindable!T _p_data;

        // provide implicit cast to wrapper of supertype
        static if (!is(Unqual!T == Object))
        {
            static if (is(BaseClassesTuple!(Unqual!T)[0]))
                alias SuperType = RefCounted!(CopyTypeQualifiers!(T, BaseClassesTuple!(Unqual!T)[0]), _userVisible);
            else
                alias SuperType = RefCounted!(CopyTypeQualifiers!(T, Object), _userVisible);

            SuperType superType()
            {
                return SuperType(_p_data);
            }
            alias superType this;
        }

        // cast the wrapped object to raw memory
        private void[] _p_dataBlock() const
        {
            void[] result = (cast(ubyte*)cast(void*)_p_data)[0..T.sizeof];
            return result;
        }

        // refcounting methods
        static if (_p_rc)
        {
            private void _p_incr()
            {
                if (_p_data)
                {
                    _p_alloc.prefix(_p_dataBlock)++;
                    static if (_userVisible && advancedRefCouting && is(typeof(T.incrVisibleRefCount)))
                        _p_data.incrVisibleRefCount;
                }
            }
            private void _p_decr()
            {
                if (_p_data)
                {
                    static if (_userVisible && advancedRefCouting && is(typeof(T.decrVisibleRefCount)))
                        _p_data.decrVisibleRefCount;
                    if (--_p_alloc.prefix(_p_dataBlock) == 0)
                        _p_alloc.deallocate(_p_dataBlock);
                }
            }
        }
        else
        {
            private void _p_incr() {}
            private void _p_decr() {}
        }

        // constructors only work for already wrapped objects
        this(typeof(null))
        {
            _p_data = null;
        }
        this(T payload)
        {
            _p_data = payload;
            _p_incr;
        }
        this(this)
        {
            _p_incr;
        }
        ~this()
        {
            _p_decr;
        }

        // comparisons
        bool opEquals(typeof(null) other) const
        {
            return _p_data is null;
        }
        bool opEquals(U, bool visibility)(const auto ref RefCounted!(U, visibility) other) const
        {
            return _p_data is other._p_data;
        }
        
        // true means not null
        bool opCast(T: bool)() const
        {
            return (_p_data)?true:false;
        }

        // assignments
        void opAssign(typeof(null) other)
        {
            _p_decr;
            _p_data = null;
        }
        void opAssign(U, bool visibility)(auto ref RefCounted!(U, visibility) other)
        {
            _p_decr;
            _p_data = other._p_data;
            _p_incr;
        }

        // only way to construct a new object
        static RefCounted emplace(Args...)(auto ref Args args)
        {
            auto result = RefCounted(_p_alloc.make!T(args));
            //result._p_data = _p_alloc.make!T(args);

            import core.memory;
            auto block = result._p_dataBlock;
            GC.addRange(block.ptr, block.length, T.classinfo);
            
            /*static if(_p_rc)
                _p_alloc.prefix(result._p_dataBlock) = 1;*/
            
            return result;
        }
        
        enum Null = RefCounted(null);

        alias UserVisible = RefCounted!(T, true);
        UserVisible userVisible()
        {
            return UserVisible(_p_data);
        }
        alias LibInternal = RefCounted!(T, false);
        LibInternal libInternal()
        {
            return LibInternal(_p_data);
        }

        RefCounted!(U, _userVisible) downCast(RC: RefCounted!(U, _userVisible), U)()
        {
            return RefCounted!(U, _userVisible)(cast(U)_p_data);
        }

        // dispatch everything to wrapped type
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
    
    // Types to be used in public APIs and user code; they keep the DOM trees alive
    alias Node = RefCounted!(_Node, true);
    alias Attr = RefCounted!(_Attr, true);
    alias CharacterData = RefCounted!(_CharacterData, true);
    alias Comment = RefCounted!(_Comment, true);
    alias Text = RefCounted!(_Text, true);
    alias CDATASection = RefCounted!(_CDATASection, true);
    alias ProcessingInstruction = RefCounted!(_ProcessingInstruction, true);
    alias EntityReference = RefCounted!(_EntityReference, true);
    alias Entity = RefCounted!(_Entity, true);
    alias Notation = RefCounted!(_Notation, true);
    alias DocumentType = RefCounted!(_DocumentType, true);
    alias Element = RefCounted!(_Element, true);
    alias Document = RefCounted!(_Document, true);
    alias DocumentFragment = RefCounted!(_DocumentFragment, true);

    // Types to be used internally; they do not keep the DOM alive and are needed to avoid
    // circular references that prevent deallocation (only if advancedRefCouting is true)
    alias WeakNode = RefCounted!(_Node);
    alias WeakAttr = RefCounted!(_Attr);
    alias WeakCharacterData = RefCounted!(_CharacterData);
    alias WeakComment = RefCounted!(_Comment);
    alias WeakText = RefCounted!(_Text);
    alias WeakCDATASection = RefCounted!(_CDATASection);
    alias WeakProcessingInstruction = RefCounted!(_ProcessingInstruction);
    alias WeakEntityReference = RefCounted!(_EntityReference);
    alias WeakEntity = RefCounted!(_Entity);
    alias WeakNotation = RefCounted!(_Notation);
    alias WeakDocumentType = RefCounted!(_DocumentType);
    alias WeakElement = RefCounted!(_Element);
    alias WeakDocument = RefCounted!(_Document);
    alias WeakDocumentFragment = RefCounted!(_DocumentFragment);

    // others
    alias NodeList = RefCounted!(_NodeList);
    alias NamedNodeMap = RefCounted!(_NamedNodeMap);
    alias NamedNodeMapImpl_ElementAttributes = RefCounted!(_NamedNodeMapImpl_ElementAttributes);

    alias UserDataHandler = void delegate(UserDataOperation, string, UserData, Node, Node);

    abstract class _Node
    {
        // REQUIRED BY THE STANDARD; TO BE IMPLEMENTED BY SUBCLASSES
        public abstract
        {
            @property StringType    namespaceUri()    const ;
            @property StringType    nodeName()        const ;
            @property NodeType      nodeType()        const ;
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
            StringType localName() const  { return null; }
            @property StringType nodeValue() { return null; }
            @property void nodeValue(StringType newValue) {}
            @property StringType prefix() const  { return null; }
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
                newChild.attachToParent;
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
                newChild.attachToParent;
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
                newChild.attachToParent;
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

            Node cloneNode(bool deep)  { return Node.Null; }
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
                alias ChildNodeList = RefCounted!(_ChildNodeList);
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

            bool hasChildNodes() const
            {
                return _firstChild != null;
            }
            bool isSameNode(in Node other)
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
        protected
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
                if (_parentNode != null)
                    return _parentNode;
                else
                    return _ownerDocument;
            }
            void destroyInternalReferences() @nogc
            {
                if (refCount == size_t.max)
                    return;
                refCount = size_t.max;
                if (_firstChild != null)
                {
                    _firstChild.destroyInternalReferences();
                    _firstChild = null;
                }
                if (_lastChild != null)
                {
                    _lastChild.destroyInternalReferences();
                    _lastChild = null;
                }
                if (_parentNode != null)
                {
                    _parentNode.destroyInternalReferences();
                    _parentNode = null;
                }
                if (_previousSibling != null)
                {
                    _previousSibling.destroyInternalReferences();
                    _previousSibling = null;
                }
                if (_nextSibling != null)
                {
                    _nextSibling.destroyInternalReferences();
                    _nextSibling = null;
                }
                if (_ownerDocument != null)
                {
                    _ownerDocument.destroyInternalReferences();
                    _ownerDocument = null;
                }
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
                auto newChild = ownerDocument.createTextNode(newValue);
                newChild._parentNode = Attr(this);
                newChild.attachToParent;
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
            @property StringType textContent() { return value; }
            @property void textContent(StringType newContent) { value = newContent; }

            @property StringType namespaceUri() const  { return _namespaceUri; }
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

            @property StringType namespaceUri() const  { return null;}
        }
    }

    class _Comment: _CharacterData
    {
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public override
        {
            @property NodeType nodeType() const  { return NodeType.COMMENT; }
            @property StringType nodeName() const  { return "#comment"; }
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
            @property NodeType nodeType() const  { return NodeType.TEXT; }
            @property StringType nodeName() const  { return "#text"; }
        }
    }

    class _CDATASection: _Text
    {
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public override
        {
            @property NodeType nodeType() const  { return NodeType.CDATA_SECTION; }
            @property StringType nodeName() const  { return "#cdata-section"; }
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
            @property NodeType nodeType() const  { return NodeType.PROCESSING_INSTRUCTION; }
            @property StringType nodeName() const  { return target; }
            @property StringType namespaceUri() const  { return null; }
        }
    }

    class _EntityReference: _Node
    {
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public override
        {
            @property NodeType nodeType() const  { return NodeType.ENTITY_REFERENCE; }
            @property StringType nodeName() const  { return null; }
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
            @property NodeType nodeType() const  { return NodeType.ENTITY; }
            @property StringType nodeName() const  { return null; }
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
            @property NodeType nodeType() const  { return NodeType.NOTATION; }
            @property StringType nodeName() const  { return null; }
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
            @property NodeType nodeType() const  { return NodeType.DOCUMENT_TYPE; }
            @property StringType nodeName() const  { return name; }
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
            const WeakDocumentType doctype;
            const DOMImplementation implementation;
            const WeakElement documentElement;

            Element createElement(StringType tagName)
            {
                auto result = Element.emplace();
                result._name = tagName;
                result._ownerDocument = Document(this);
                return result;
            }
            Element createElementNS(StringType namespaceUri, StringType qualifiedName)
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
            Text createTextNode(StringType text) const
            {
                auto result = Text.emplace();
                result.data = text;
                return result;
            }
            Comment createComment(StringType text) const
            {
                auto result = Comment.emplace();
                result.data = text;
                return result;
            }
            CDATASection createCDataSection(StringType text) const
            {
                auto result = CDATASection.emplace();
                result.data = text;
                return result;
            }
            ProcessingInstruction createProcessingInstruction(StringType target, StringType data) const
            {
                auto result = ProcessingInstruction.emplace();
                result.target = target;
                result.data = data;
                return result;
            }
            Attr createAttribute(StringType name)
            {
                auto result = Attr.emplace();
                result._name = name;
                result._ownerDocument = Document(this);
                return result;
            }
            Attr createAttributeNS(StringType namespaceUri, StringType qualifiedName)
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
            @property NodeType nodeType() const  { return NodeType.DOCUMENT_FRAGMENT; }
            @property StringType nodeName() const  { return "#document-fragment"; }
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
            abstract ulong length() const ;
            abstract Node item(ulong index);

            abstract Node getNamedItem(StringType name);
            abstract Node setNamedItem(Node arg);
            abstract Node removeNamedItem(StringType name);

            abstract Node getNamedItemNS(StringType namespaceUri, StringType localName) ;
            abstract Node setNamedItemNS(Node arg);
            abstract Node removeNamedItemNS(StringType namespaceUri, StringType localName);
        }
    }

    private class _NamedNodeMapImpl_ElementAttributes: _NamedNodeMap
    {
        // REQUIRED BY THE STANDARD; INHERITED FROM SUPERCLASS
        public override
        {
            ulong length() const
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

            Node getNamedItem(StringType name)
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

            Node getNamedItemNS(StringType namespaceUri, StringType localName)
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

mixin template InjectDOM(StringType, alias Alloc = GCAllocator, string prefix = "", string suffix = "")
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
    assert(element.childNodes.item(0).textContent == "Some useful insight...");
}
