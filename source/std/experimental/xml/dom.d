/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module declares the DOM Level 3 interfaces as stated in the W3C DOM
+   specification.
+
+   For a more complete reference, see the
+   $(LINK2 https://www.w3.org/TR/DOM-Level-3-Core/, official specification),
+   from which all documentation in this module is taken.
+
+   Authors:
+   Lodovico Giaretta
+
+   License:
+   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
+
+   Copyright:
+   Copyright Lodovico Giaretta 2016 --
+/

module std.experimental.xml.dom;

import std.typecons: BitFlags;
import std.variant: Variant;

/++
+   The DOMUserData type is used to store application data.
+/
alias UserData = Variant;

/++
+   When associating an object to a key on a node using Node.setUserData() the
+   application can provide a handler that gets called when the node the object
+   is associated to is being cloned, imported, or renamed. This can be used by
+   the application to implement various behaviors regarding the data it associates
+   to the DOM nodes.
+/
alias UserDataHandler(DOMString) = void delegate(UserDataOperation, DOMString, UserData, Node!DOMString, Node!DOMString);

/++
+   An integer indicating which type of node this is.
+
+   Note:
+   Numeric codes up to 200 are reserved to W3C for possible future use.
+/
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

/++
+   A bitmask indicating the relative document position of a node with respect to another node.
+
+   If the two nodes being compared are the same node, then no flags are set on the return.
+
+   Otherwise, the order of two nodes is determined by looking for common containers --
+   containers which contain both. A node directly contains any child nodes. A node
+   also directly contains any other nodes attached to it such as attributes contained
+   in an element or entities and notations contained in a document type. Nodes contained
+   in contained nodes are also contained, but less-directly as the number of intervening
+   containers increases.
+
+   If there is no common container node, then the order is based upon order between
+   the root container of each node that is in no container. In this case, the result
+   is disconnected and implementation-specific. This result is stable as long as these
+   outer-most containing nodes remain in memory and are not inserted into some other
+   containing node. This would be the case when the nodes belong to different documents
+   or fragments, and cloning the document or inserting a fragment might change the order.
+
+   If one of the nodes being compared contains the other node, then the container precedes
+   the contained node, and reversely the contained node follows the container. For example,
+   when comparing an element against its own attribute or child, the element node precedes
+   its attribute node and its child node, which both follow it.
+
+   If neither of the previous cases apply, then there exists a most-direct container
+   common to both nodes being compared. In this case, the order is determined based
+   upon the two determining nodes directly contained in this most-direct common
+   container that either are or contain the corresponding nodes being compared.
+
+   If these two determining nodes are both child nodes, then the natural DOM order
+   of these determining nodes within the containing node is returned as the order
+   of the corresponding nodes. This would be the case, for example, when comparing
+   two child elements of the same element.
+
+   If one of the two determining nodes is a child node and the other is not, then
+   the corresponding node of the child node follows the corresponding node of the
+   non-child node. This would be the case, for example, when comparing an attribute
+   of an element with a child element of the same element.
+
+   If neither of the two determining node is a child node and one determining node
+   has a greater value of nodeType than the other, then the corresponding node precedes
+   the other. This would be the case, for example, when comparing an entity of a document
+   type against a notation of the same document type.
+
+   If neither of the two determining node is a child node and nodeType is the same
+   for both determining nodes, then an implementation-dependent order between the
+   determining nodes is returned. This order is stable as long as no nodes of the
+   same nodeType are inserted into or removed from the direct container. This would
+   be the case, for example, when comparing two attributes of the same element, and
+   inserting or removing additional attributes might change the order between existing
+   attributes.
+/
enum DocumentPosition: ushort
{
    NONE         = 0,
    DISCONNECTED = 1,
    PRECEDING    = 2,
    FOLLOWING    = 4,
    CONTAINS     = 8,
    CONTAINED_BY = 16,
    IMPLEMENTATION_SPECIFIC = 32,
}

/++
+   An integer indicating the type of operation being performed on a node.
+/
enum UserDataOperation: ushort
{
    /// The node is cloned, using `Node.cloneNode()`.
    NODE_CLONED = 1,
    /// The node is imported, using `Document.importNode()`.
    NODE_IMPORTED,
    /++
    +   The node is deleted.
    +   Note:
    +   This may not be supported or may not be reliable in certain environments,
    +   where the implementation has no real control over when objects are actually deleted.
    +/
    NODE_DELETED,
    /// The node is renamed, using `Document.renameNode()`.
    NODE_RENAMED,
    /// The node is adopted, using `Document.adoptNode()`.
    NODE_ADOPTED,
}

/++
+   An integer indicating the type of error generated.
+
+   Note:
+   Other numeric codes are reserved for W3C for possible future use.
+/
enum ExceptionCode: ushort
{
    /// If index or size is negative, or greater than the allowed value.
    INDEX_SIZE,
    /// If the specified range of text does not fit into a DOMString.
    DOMSTRING_SIZE,
    /// If any Node is inserted somewhere it doesn't belong.
    HIERARCHY_REQUEST,
    /// If a Node is used in a different document than the one that created it (that doesn't support it).
    WRONG_DOCUMENT,
    /// If an invalid or illegal character is specified, such as in an XML name.
    INVALID_CHARACTER,
    /// If data is specified for a Node which does not support data.
    NO_DATA_ALLOWED,
    /// If an attempt is made to modify an object where modifications are not allowed.
    NO_MODIFICATION_ALLOWED,
    /// If an attempt is made to reference a Node in a context where it does not exist.
    NOT_FOUND,
    /// If the implementation does not support the requested type of object or operation.
    NOT_SUPPORTED,
    /// If an attempt is made to add an attribute that is already in use elsewhere.
    INUSE_ATTRIBUTE,
    /// If an attempt is made to use an object that is not, or is no longer, usable.
    INVALID_STATE,
    /// If an invalid or illegal string is specified.
    SYNTAX,
    /// If an attempt is made to modify the type of the underlying object.
    INVALID_MODIFICATION,
    /// If an attempt is made to create or change an object in a way which is incorrect with regard to namespaces.
    NAMESPACE,
    /// If a parameter or an operation is not supported by the underlying object.
    INVALID_ACCESS,
    /// If a call to a method such as insertBefore or removeChild would make the Node invalid.
    VALIDATION,
    /// If the type of an object is incompatible with the expected type of the parameter associated to the object.
    TYPE_MISMATCH,
}

/// An integer indicating the severity of the error.
enum ErrorSeverity: ushort
{
    /++
    +   The severity of the error described by the DOMError is warning. A `WARNING`
    +   will not cause the processing to stop, unless DOMErrorHandler.handleError() returns false.
    +/
    WARNING,
    /++
    +   The severity of the error described by the DOMError is error. A `ERROR`
    +   may not cause the processing to stop if the error can be recovered, unless
    +   DOMErrorHandler.handleError() returns false.
    +/
    ERROR,
    /++
    +   The severity of the error described by the `DOMError` is fatal error. A `FATAL_ERROR`
    +   will cause the normal processing to stop. The return value of DOMErrorHandler.handleError()
    +   is ignored unless the implementation chooses to continue, in which case the behavior becomes undefined.
    +/
    FATAL_ERROR,
}

enum DerivationMethod: ulong
{
    DERIVATION_RESTRICTION = 0x00000001,
    DERIVATION_EXTENSION   = 0x00000002,
    DERIVATION_UNION       = 0x00000004,
    DERIVATION_LIST        = 0x00000008,
}

/++
+   DOM operations only raise exceptions in "exceptional" circumstances, i.e.,
+   when an operation is impossible to perform (either for logical reasons, because
+   data is lost, or because the implementation has become unstable). In general,
+   DOM methods return specific error values in ordinary processing situations,
+   such as out-of-bound errors when using `NodeList`.
+
+   Implementations should raise other exceptions under other circumstances. For
+   example, implementations should raise an implementation-dependent exception
+   if a `null` argument is passed when `null` was not expected.
+/
abstract class DOMException: Exception
{
    ///
    @property ExceptionCode code();
    
    /// 
    pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/++
+   The `DOMStringList` interface provides the abstraction of an ordered collection
+   of `DOMString` values, without defining or constraining how this collection is
+   implemented. The items in the DOMStringList are accessible via an integral index,
+   starting from `0`.
+/
interface DOMStringList(DOMString)
{
    DOMString item(size_t index);
    @property size_t length();
    bool contains(DOMString str);
};

/++
+   The `DOMImplementationList` interface provides the abstraction of an ordered
+   collection of DOM implementations, without defining or constraining how this
+   collection is implemented. The items in the `DOMImplementationList` are accessible
+   via an integral index, starting from `0`.
+/
interface DOMImplementationList(DOMString)
{
    DOMImplementation!DOMString item(size_t index);
    @property size_t length();
}

/++
+   This interface permits a DOM implementer to supply one or more implementations,
+   based upon requested features and versions, as specified in DOM Features.
+   Each implemented DOMImplementationSource object is listed in the binding-specific
+   list of available sources so that its `DOMImplementation` objects are made available.
+/
interface DOMImplementationSource(DOMString)
{
    /// A method to request the first DOM implementation that supports the specified features.
    DOMImplementation!DOMString getDOMImplementation(DOMString features);
    /// A method to request a list of DOM implementations that support the specified features and versions, as specified in DOM Features.
    DOMImplementationList!DOMString getDOMImplementationList(DOMString features);
}

/++
+   The DOMImplementation interface provides a number of methods for performing
+   operations that are independent of any particular instance of the document object model.
+/
interface DOMImplementation(DOMString)
{
    /++
    +   Creates an empty DocumentType node. Entity declarations and notations are not
    +   made available. Entity reference expansions and default attribute additions do not occur.
    +/
    DocumentType!DOMString createDocumentType(DOMString qualifiedName, DOMString publicId, DOMString systemId); //raises(DOMException)
    
    /++
    +   Creates a DOM Document object of the specified type with its document element.
    +
    +   Note that based on the DocumentType given to create the document, the implementation
    +   may instantiate specialized Document objects that support additional features than the "Core",
    +   such as "HTML". On the other hand, setting the DocumentType after the document
    +   was created makes this very unlikely to happen.
    +/
    Document!DOMString createDocument(DOMString namespaceURI, DOMString qualifiedName, DocumentType!DOMString doctype); //raises(DOMException)
    
    bool hasFeature(string feature, string version_);
    Object getFeature(string feature, string version_);
}

/++
+   `DocumentFragment` is a "lightweight" or "minimal" `Document` object. It is very
+   common to want to be able to extract a portion of a document's tree or to create
+   a new fragment of a document. Imagine implementing a user command like cut or
+   rearranging a document by moving fragments around. It is desirable to have an
+   object which can hold such fragments and it is quite natural to use a `Node`
+   for this purpose. While it is true that a `Document` object could fulfill this
+   role, a `Document` object can potentially be a heavyweight object, depending
+   on the underlying implementation. What is really needed for this is a very lightweight
+   object. `DocumentFragment` is such an object.
+
+   Furthermore, various operations -- such as inserting nodes as children of another
+   `Node` -- may take `DocumentFragment` objects as arguments; this results in
+   all the child nodes of the `DocumentFragment` being moved to the child list of this node.
+
+   The children of a `DocumentFragment` node are zero or more nodes representing
+   the tops of any sub-trees defining the structure of the document. `DocumentFragment`
+   nodes do not need to be well-formed XML documents (although they do need to follow
+   the rules imposed upon well-formed XML parsed entities, which can have multiple
+   top nodes). For example, a `DocumentFragment` might have only one child and that
+   child node could be a `Text` node. Such a structure model represents neither
+   an HTML document nor a well-formed XML document.
+
+   When a `DocumentFragment` is inserted into a `Document` (or indeed any other
+   `Node` that may take children) the children of the `DocumentFragment` and not
+   the `DocumentFragment` itself are inserted into the `Node`. This makes the `DocumentFragment`
+   very useful when the user wishes to create nodes that are siblings; the `DocumentFragment`
+   acts as the parent of these nodes so that the user can use the standard methods
+   from the `Node` interface, such as `Node.insertBefore` and `Node.appendChild`.
+/
interface DocumentFragment(DOMString): Node!DOMString
{
}

/++
+   The `Document` interface represents the entire HTML or XML document. Conceptually,
+   it is the root of the document tree, and provides the primary access to the document's data.
+
+   Since elements, text nodes, comments, processing instructions, etc. cannot exist
+   outside the context of a `Document`, the `Document` interface also contains the
+   factory methods needed to create these objects. The `Node` objects created have
+   a `ownerDocument` attribute which associates them with the `Document` within
+   whose context they were created.
+/
interface Document(DOMString): Node!DOMString
{
    @property DocumentType!DOMString doctype();
    @property DOMImplementation!DOMString implementation();
    @property Element!DOMString documentElement();

    Element!DOMString createElement(DOMString tagName); //raises(DOMException)
    Element!DOMString createElementNS(DOMString namespaceURI, DOMString qualifiedName); //raises(DOMException)
    DocumentFragment!DOMString createDocumentFragment();
    Text!DOMString createTextNode(DOMString data);
    Comment!DOMString createComment(DOMString data);
    CDATASection!DOMString createCDATASection(DOMString data); //raises(DOMException)
    ProcessingInstruction!DOMString createProcessingInstruction(DOMString target, DOMString data); //raises(DOMException)
    Attr!DOMString createAttribute(DOMString name); //raises(DOMException)
    Attr!DOMString createAttributeNS(DOMString namespaceURI, DOMString qualifiedName); //raises(DOMException)
    EntityReference!DOMString createEntityReference(DOMString name); //raises(DOMException)

    NodeList!DOMString getElementsByTagName(DOMString tagname);
    NodeList!DOMString getElementsByTagNameNS(DOMString namespaceURI, DOMString localName);
    Element!DOMString getElementById(DOMString elementId);

    Node!DOMString importNode(Node!DOMString importedNode, bool deep); //raises(DOMException)
    Node!DOMString adoptNode(Node!DOMString source); // raises(DOMException)

    @property DOMString inputEncoding();
    @property DOMString xmlEncoding();
    
    @property bool xmlStandalone();
    @property void xmlStandalone(bool); // raises(DOMException) on setting

    @property DOMString xmlVersion();
    @property void xmlVersion(DOMString); // raises(DOMException) on setting

    @property bool strictErrorChecking();
    @property void strictErrorChecking(bool);
    
    @property DOMString documentURI();
    @property void documentURI(DOMString);
    
    @property DOMConfiguration!DOMString domConfig();
    void normalizeDocument();
    Node!DOMString renameNode(Node!DOMString n, DOMString namespaceURI, DOMString qualifiedName); //raises(DOMException)
}

/++
+   The `Node` interface is the primary datatype for the entire Document Object Model.
+   It represents a single node in the document tree. While all objects implementing
+   the `Node` interface expose methods for dealing with children, not all objects
+   implementing the `Node` interface may have children. For example, `Text` nodes
+   may not have children, and adding children to such nodes results in a `DOMException`
+   being raised.
+
+   The attributes `nodeName`, `nodeValue` and `attributes` are included as a mechanism
+   to get at node information without casting down to the specific derived interface.
+   In cases where there is no obvious mapping of these attributes for a specific `nodeType`
+   (e.g., `nodeValue` for an `Element` or attributes for a `Comment`), this returns `null`.
+   Note that the specialized interfaces may contain additional and more convenient
+   mechanisms to get and set the relevant information.
+/
interface Node(DOMString)
{
    @property NodeType nodeType();
    @property DOMString nodeName();
    @property DOMString localName();
    @property DOMString prefix();
    @property void prefix(DOMString); // raises(DOMException) on setting
    @property DOMString namespaceURI();
    @property DOMString baseURI();
    
    @property DOMString nodeValue(); // raises(DOMException) on retrieval
    @property void nodeValue(DOMString); // raises(DOMException) on setting
    @property DOMString textContent(); // raises(DOMException) on retrieval
    @property void textContent(DOMString); // raises(DOMException) on setting
    
    @property Node!DOMString parentNode();
    @property NodeList!DOMString childNodes();
    @property Node!DOMString firstChild();
    @property Node!DOMString lastChild();
    @property Node!DOMString previousSibling();
    @property Node!DOMString nextSibling();
    @property Document!DOMString ownerDocument();
    
    @property NamedNodeMap!DOMString attributes();
    bool hasAttributes();
    
    Node!DOMString insertBefore(Node!DOMString newChild, Node!DOMString refChild); //raises(DOMException)
    Node!DOMString replaceChild(Node!DOMString newChild, Node!DOMString oldChild); //raises(DOMException)
    Node!DOMString removeChild(Node!DOMString oldChild); //raises(DOMException)
    Node!DOMString appendChild(Node!DOMString newChild); //raises(DOMException)
    bool hasChildNodes();
    
    Node!DOMString cloneNode(bool deep);
    bool isSameNode(Node!DOMString other);
    bool isEqualNode(Node!DOMString arg);
    
    void normalize();
    
    bool isSupported(string feature, string version_);
    Object getFeature(string feature, string version_);
    
    UserData getUserData(string key);
    UserData setUserData(string key, UserData data, UserDataHandler!DOMString handler);

    BitFlags!DocumentPosition compareDocumentPosition(Node!DOMString other); //raises(DOMException)

    DOMString lookupPrefix(DOMString namespaceURI);
    DOMString lookupNamespaceURI(DOMString prefix);
    bool isDefaultNamespace(DOMString namespaceURI);
}

/++
+   The `NodeList` interface provides the abstraction of an ordered collection of
+   nodes, without defining or constraining how this collection is implemented.
+   `NodeList` objects in the DOM are live.
+
+   The items in the `NodeList` are accessible via an integral index, starting from `0`.
+/
interface NodeList(DOMString)
{
    Node!DOMString item(size_t index);
    @property size_t length();
}

/++
+   Objects implementing the `NamedNodeMap` interface are used to represent collections
+   of nodes that can be accessed by name. Note that `NamedNodeMap` does not inherit
+   from `NodeList`; `NamedNodeMaps` are not maintained in any particular order.
+   Objects contained in an object implementing `NamedNodeMap` may also be accessed
+   by an ordinal index, but this is simply to allow convenient enumeration of the
+   contents of a `NamedNodeMap`, and does not imply that the DOM specifies an order
+   to these `Node`s.
+
+   `NamedNodeMap` objects in the DOM are live.
+/
interface NamedNodeMap(DOMString)
{
    Node!DOMString item(size_t index);
    @property size_t length();

    Node!DOMString getNamedItem(DOMString name);
    Node!DOMString setNamedItem(Node!DOMString arg); //raises(DOMException)
    Node!DOMString removeNamedItem(DOMString name); //raises(DOMException)

    Node!DOMString getNamedItemNS(DOMString namespaceURI, DOMString localName); //raises(DOMException)
    Node!DOMString setNamedItemNS(Node!DOMString arg); //raises(DOMException)
    Node!DOMString removeNamedItemNS(DOMString namespaceURI, DOMString localName); //raises(DOMException)
}

/++
+   The `CharacterData` interface extends `Node` with a set of attributes and methods
+   for accessing character data in the DOM. For clarity this set is defined here
+   rather than on each object that uses these attributes and methods. No DOM objects
+   correspond directly to `CharacterData`, though `Text` and others do inherit
+   the interface from it. All offsets in this interface start from `0`.
+/
interface CharacterData(DOMString): Node!DOMString
{
    @property DOMString data(); // raises(DOMException) on setting
    @property void data(DOMString); // raises(DOMException) on retrieval
    
    @property size_t length();
    
    DOMString substringData(size_t offset, size_t count); //raises(DOMException)
    void appendData(DOMString arg); //raises(DOMException)
    void insertData(size_t offset, DOMString arg); //raises(DOMException)
    void deleteData(size_t offset, size_t count); //raises(DOMException)
    void replaceData(size_t offset, size_t count, DOMString arg); //raises(DOMException)
}

interface Attr(DOMString): Node!DOMString
{
    @property DOMString name();
    @property bool specified();
    @property DOMString value();
    @property void value(DOMString); // raises(DOMException) on setting

    @property Element!DOMString ownerElement();
    @property XMLTypeInfo!DOMString schemaTypeInfo();
    @property bool isId();
}

interface Element(DOMString): Node!DOMString
{
    @property DOMString tagName();
    
    DOMString getAttribute(DOMString name);
    void setAttribute(DOMString name, DOMString value); //raises(DOMException)
    void removeAttribute(DOMString name); //raises(DOMException)
    
    Attr!DOMString getAttributeNode(DOMString name);
    Attr!DOMString setAttributeNode(Attr!DOMString newAttr); //raises(DOMException)
    Attr!DOMString removeAttributeNode(Attr!DOMString oldAttr); //raises(DOMException)
    
    DOMString getAttributeNS(DOMString namespaceURI, DOMString localName); //raises(DOMException)
    void setAttributeNS(DOMString namespaceURI, DOMString qualifiedName, DOMString value); //raises(DOMException)
    void removeAttributeNS(DOMString namespaceURI, DOMString localName); //raises(DOMException)
    
    Attr!DOMString getAttributeNodeNS(DOMString namespaceURI, DOMString localName); //raises(DOMException)
    Attr!DOMString setAttributeNodeNS(Attr!DOMString newAttr); //raises(DOMException)
    
    bool hasAttribute(DOMString name);
    bool hasAttributeNS(DOMString namespaceURI, DOMString localName); //raises(DOMException)
    
    void setIdAttribute(DOMString name, bool isId); //raises(DOMException)
    void setIdAttributeNS(DOMString namespaceURI, DOMString localName, bool isId); //raises(DOMException)
    void setIdAttributeNode(Attr!DOMString idAttr, bool isId); //raises(DOMException)
    
    NodeList!DOMString getElementsByTagName(DOMString name);
    NodeList!DOMString getElementsByTagNameNS(DOMString namespaceURI, DOMString localName); //raises(DOMException)
    
    @property XMLTypeInfo!DOMString schemaTypeInfo();
}

interface Text(DOMString): CharacterData!DOMString
{
    Text!DOMString splitText(size_t offset); //raises(DOMException)
    
    @property bool isElementContentWhitespace();
    
    @property DOMString wholeText();
    Text!DOMString replaceWholeText(DOMString content); //raises(DOMException)
}

interface Comment(DOMString): CharacterData!DOMString
{
}

interface XMLTypeInfo(DOMString)
{
    @property DOMString typeName();
    @property DOMString typeNamespace();

    bool isDerivedFrom(DOMString typeNamespaceArg, DOMString typeNameArg, DerivationMethod derivationMethod);
}

interface DOMError(DOMString)
{
    @property ErrorSeverity severity();
    @property DOMString message();
    @property DOMString type();
    @property Object relatedException();
    @property Object relatedData();
    @property DOMLocator!DOMString location();
}

interface DOMLocator(DOMString)
{
    @property long lineNumber();
    @property long columnNumber();
    @property long byteOffset();
    @property long utf16Offset();
    @property Node!DOMString relatedNode();
    @property DOMString uri();
}

interface DOMConfiguration(DOMString)
{
    void setParameter(string name, UserData value); //raises(DOMException)
    UserData getParameter(string name); //raises(DOMException)
    bool canSetParameter(string name, UserData value);
    @property DOMStringList!string parameterNames();
}

interface CDATASection(DOMString): Text!DOMString
{
}

interface DocumentType(DOMString): Node!DOMString
{
    @property DOMString name();
    @property NamedNodeMap!DOMString entities();
    @property NamedNodeMap!DOMString notations();
    @property DOMString publicId();
    @property DOMString systemId();
    @property DOMString internalSubset();
}

interface Notation(DOMString): Node!DOMString
{
    @property DOMString publicId();
    @property DOMString systemId();
}

interface Entity(DOMString): Node!DOMString
{
    @property DOMString publicId();
    @property DOMString systemId();
    @property DOMString notationName();
    @property DOMString inputEncoding();
    @property DOMString xmlEncoding();
    @property DOMString xmlVersion();
}

interface EntityReference(DOMString): Node!DOMString
{
}

interface ProcessingInstruction(DOMString): Node!DOMString
{
    @property DOMString target();
    @property DOMString data();
    @property void data(DOMString); // raises(DOMException) on setting
}