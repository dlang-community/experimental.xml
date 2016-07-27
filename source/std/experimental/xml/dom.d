/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements the DOM Level 3 interfaces as stated in the W3C DOM
+   specification.
+/

module std.experimental.xml.dom;

import std.variant: Variant;
alias UserData = Variant;
alias UserDataHandler(DOMString) = void delegate(UserDataOperation, DOMString, UserData, Node!DOMString, Node!DOMString);

enum NodeType: ushort
{
    ELEMENT,
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
    INDEX_SIZE,
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
enum ErrorSeverity: ushort
{
    SEVERITY_WARNING,
    SEVERITY_ERROR,
    SEVERITY_FATAL_ERROR,
}
enum DerivationMethod: ulong
{
    DERIVATION_RESTRICTION = 0x00000001,
    DERIVATION_EXTENSION   = 0x00000002,
    DERIVATION_UNION       = 0x00000004,
    DERIVATION_LIST        = 0x00000008,
}

abstract class DOMException: Exception
{
    @property ExceptionCode code();
    
    pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

interface DOMStringList(DOMString)
{
    DOMString item(size_t index);
    @property size_t length();
    bool contains(DOMString str);
};

interface DOMImplementationList(DOMString)
{
    DOMImplementation!DOMString item(size_t index);
    @property size_t length();
}

interface DOMImplementationSource(DOMString)
{
    DOMImplementation!DOMString getDOMImplementation(DOMString features);
    DOMImplementationList!DOMString getDOMImplementationList(DOMString features);
}

interface DOMImplementation(DOMString)
{
    DocumentType!DOMString createDocumentType(DOMString qualifiedName, DOMString publicId, DOMString systemId); //raises(DOMException)
    Document!DOMString createDocument(DOMString namespaceURI, DOMString qualifiedName, DocumentType!DOMString doctype); //raises(DOMException)
    
    bool hasFeature(DOMString feature, DOMString version_);
    Object getFeature(DOMString feature, DOMString version_);
}

interface DocumentFragment(DOMString): Node!DOMString
{
}

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
    
    bool isSupported(DOMString feature, DOMString version_);
    Object getFeature(DOMString feature, DOMString version_);
    
    UserData getUserData(string key);
    UserData setUserData(string key, UserData data, UserDataHandler!DOMString handler);

    DocumentPosition compareDocumentPosition(Node!DOMString other); //raises(DOMException)

    DOMString lookupPrefix(DOMString namespaceURI);
    DOMString lookupNamespaceURI(DOMString prefix);
    bool isDefaultNamespace(DOMString namespaceURI);
}

interface NodeList(DOMString)
{
    Node!DOMString item(size_t index);
    @property size_t length();
}

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
    @property DOMLocator location();
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
    void setParameter(DOMString name, UserData value); //raises(DOMException)
    UserData getParameter(DOMString name); //raises(DOMException)
    bool canSetParameter(DOMString name, UserData value);
    @property DOMStringList!DOMString parameterNames();
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

// Code to find all DOM implementations available at compile-time

struct RegisterDOMImplementationSource
{
}