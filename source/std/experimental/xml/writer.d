/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements components to put XML data in `OutputRange`s
+/

module std.experimental.xml.writer;

import std.experimental.xml.interfaces;

private string ifCompiles(string code)
{
    return "static if (__traits(compiles, " ~ code ~ ")) " ~ code ~ ";\n";
}
private string ifCompilesElse(string code, string fallback)
{
    return "static if (__traits(compiles, " ~ code ~ ")) " ~ code ~ "; else " ~ fallback ~ ";\n";
}
private string ifAnyCompiles(string code, string[] codes...)
{
    if (codes.length == 0)
        return "static if (__traits(compiles, " ~ code ~ ")) " ~ code ~ ";";
    else
        return "static if (__traits(compiles, " ~ code ~ ")) " ~ code ~ "; else " ~ ifAnyCompiles(codes[0], codes[1..$]);
}

import std.typecons: tuple;
private auto xmlDeclarationAttributes(StringType, Args...)(Args args)
{
    static assert(Args.length <= 3, "Too many arguments for xml declaration");

    // version specification
    static if (is(Args[0] == int))
    {
        assert(args[0] == 10 || args[0] == 11, "Invalid xml version specified");
        StringType versionString = args[0] == 10 ? "1.0" : "1.1";
        auto args1 = args[1..$];
    }
    else
    {
        StringType versionString = [];
        auto args1 = args;
    }
    
    // encoding specification
    static if (is(typeof(args1[0]) == StringType))
    {
        auto encodingString = args1[0];
        auto args2 = args1[1..$];
    }
    else
    {
        StringType encodingString = [];
        auto args2 = args1;
    }
    
    // standalone specification
    static if (is(typeof(args2[0]) == bool))
    {
        StringType standaloneString = args2[0] ? "yes" : "no";
        auto args3 = args2[1..$];
    }
    else
    {
        StringType standaloneString = [];
        auto args3 = args2;
    }
    
    // catch other erroneous parameters
    static assert(typeof(args3).length == 0, "Unrecognized attribute type for xml declaration: " ~ typeof(args3[0]).stringof);
    
    return tuple(versionString, encodingString, standaloneString);
}

/++
+   A collection of ready-to-use pretty-printers
+/
struct PrettyPrinters
{
    /++
    +   The minimal pretty-printer. It just guarantees that the input satisfies
    +   the xml grammar.
    +/
    struct Minimalizer(StringType)
    {
        // minimum requirements needed for correctness
        enum StringType beforeAttributeName = " ";
        enum StringType betweenPITargetData = " ";
    }
    /++
    +   A pretty-printer that indents the nodes with a tabulation character
    +   `'\t'` per level of nesting.
    +/
    struct Indenter(StringType)
    {
        // inherit minimum requirements 
        Minimalizer!StringType minimalizer;
        alias minimalizer this;
    
        enum StringType afterNode = "\n";
        enum StringType attributeDelimiter = "'";
        
        uint indentation;
        enum StringType tab = "\t";
        void decreaseLevel() { indentation--; }
        void increaseLevel() { indentation++; }
        
        void beforeNode(Out)(ref Out output)
        {
            foreach (i; 0..indentation)
                output.put(tab);
        }
    }
}

/++
+   Component that outputs XML data to an `OutputRange`.
+/
struct Writer(_StringType, alias OutRange, alias PrettyPrinter = PrettyPrinters.Minimalizer)
{
    alias StringType = _StringType;

    static if (is(PrettyPrinter))
        PrettyPrinter prettyPrinter;
    else static if (is(PrettyPrinter!StringType))
        PrettyPrinter!StringType prettyPrinter;
    else
        static assert(0, "Invalid pretty printer type for string type " ~ StringType.stringof);
        
    static if (is(OutRange))
        private OutRange* output;
    else static if (is(OutRange!StringType))
        private OutRange!StringType* output;
    else
        static assert(0, "Invalid output range type for string type " ~ StringType.stringof);
    
    bool startingTag = false, insideDTD = false;
    
    this(typeof(prettyPrinter) pretty)
    {
        prettyPrinter = pretty;
    }
    
    void setSink(ref typeof(*output) output)
    {
        this.output = &output;
    }
    void setSink(typeof(output) output)
    {
        this.output = output;
    }
    
    private template expand(string methodName)
    {
        import std.meta: AliasSeq;
        alias expand = AliasSeq!(
            "prettyPrinter." ~ methodName ~ "(output)",
            "output.put(prettyPrinter." ~ methodName ~ ")"
        );
    }
    private template formatAttribute(string attribute)
    {
        import std.meta: AliasSeq;
        alias formatAttribute = AliasSeq!(
            "prettyPrinter.formatAttribute(output, " ~ attribute ~ ")",
            "output.put(prettyPrinter.formatAttribute(" ~ attribute ~ "))",
            "defaultFormatAttribute(" ~ attribute ~ ", prettyPrinter.attributeDelimiter)",
            "defaultFormatAttribute(" ~ attribute ~ ")"
        );
    }
    
    private void defaultFormatAttribute(StringType attribute, StringType delimiter = "'")
    {
        // TODO: delimiter escaping
        output.put(delimiter);
        output.put(attribute);
        output.put(delimiter);
    }
    
    /++
    +   Outputs an XML declaration.
    +   
    +   Its arguments must be an `int` specifying the version
    +   number (`10` or `11`), a string specifying the encoding (no check is performed on
    +   this parameter) and a `bool` specifying the standalone property of the document.
    +   Any argument can be skipped, but the specified arguments must respect the stated
    +   ordering (which is also the ordering required by the XML specification).
    +/
    void writeXMLDeclaration(Args...)(Args args)
    {
        auto attrs = xmlDeclarationAttributes!StringType(args);
        
        output.put("<?xml");
    
        if (attrs[0])
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output.put("version");
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output.put("=");
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"attrs[0]"));
        }
        if (attrs[1])
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output.put("encoding");
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output.put("=");
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"attrs[1]"));
        }
        if (attrs[2])
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output.put("standalone");
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output.put("=");
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"attrs[2]"));
        }
        
        output.put("?>");
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    void writeXMLDeclaration(StringType version_, StringType encoding, StringType standalone)
    {   
        output.put("<?xml");
    
        if (version_)
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output.put("version");
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output.put("=");
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"version_"));
        }
        if (encoding)
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output.put("encoding");
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output.put("=");
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"encoding"));
        }
        if (standalone)
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output.put("standalone");
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output.put("=");
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"standalone"));
        }
        
        output.put("?>");
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    
    /++
    +   Outputs a comment with the given content.
    +/
    void writeComment(StringType comment)
    {
        closeOpenThings;
    
        mixin(ifAnyCompiles(expand!"beforeNode"));
        output.put("<!--");
        mixin(ifAnyCompiles(expand!"afterCommentStart"));
        
        mixin(ifCompilesElse(
            "prettyPrinter.formatComment(output, comment)",
            "output.put(comment)"
        ));
        
        mixin(ifAnyCompiles(expand!"beforeCommentEnd"));
        output.put("-->");
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    /++
    +   Outputs a text node with the given content.
    +/
    void writeText(StringType text)
    {
        //assert(!insideDTD);
        closeOpenThings;
    
        mixin(ifAnyCompiles(expand!"beforeNode"));
        mixin(ifCompilesElse(
            "prettyPrinter.formatText(output, comment)",
            "output.put(text)"
        ));
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    /++
    +   Outputs a CDATA section with the given content.
    +/
    void writeCDATA(StringType cdata)
    {
        assert(!insideDTD);
        closeOpenThings;
    
        mixin(ifAnyCompiles(expand!"beforeNode"));
        output.put("<![CDATA[[");
        output.put(cdata);
        output.put("]]>");
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    /++
    +   Outputs a processing instruction with the given target and data.
    +/
    void writeProcessingInstruction(StringType target, StringType data)
    {
        closeOpenThings;
    
        mixin(ifAnyCompiles(expand!"beforeNode"));
        output.put("<?");
        output.put(target);
        mixin(ifAnyCompiles(expand!"betweenPITargetData"));
        output.put(data);
        
        mixin(ifAnyCompiles(expand!"beforePIEnd"));
        output.put("?>");
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    
    private void closeOpenThings()
    {
        if (startingTag)
        {
            mixin(ifAnyCompiles(expand!"beforeElementEnd"));
            output.put(">");
            mixin(ifAnyCompiles(expand!"afterNode"));
            startingTag = false;
            mixin(ifCompiles("prettyPrinter.increaseLevel"));
        }
    }
    
    void startElement(StringType tagName)
    {
        closeOpenThings();
        
        mixin(ifAnyCompiles(expand!"beforeNode"));
        output.put("<");
        output.put(tagName);
        startingTag = true;
    }
    void closeElement(StringType tagName)
    {
        bool selfClose;
        mixin(ifCompilesElse(
            "selfClose = prettyPrinter.selfClosingElements",
            "selfClose = true"
        ));
        
        if (selfClose && startingTag)
        {
            mixin(ifAnyCompiles(expand!"beforeElementEnd"));
            output.put("/>");
            startingTag = false;
        }
        else
        {
            closeOpenThings;
            
            mixin(ifCompiles("prettyPrinter.decreaseLevel"));
            mixin(ifAnyCompiles(expand!"beforeNode"));
            output.put("</");
            output.put(tagName);
            mixin(ifAnyCompiles(expand!"beforeElementEnd"));
            output.put(">");
        }
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    void writeAttribute(StringType name, StringType value)
    {
        assert(startingTag, "Cannot write attribute outside element start");
        
        mixin(ifAnyCompiles(expand!"beforeAttributeName"));
        output.put(name);
        mixin(ifAnyCompiles(expand!"afterAttributeName"));
        output.put("=");
        mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
        mixin(ifAnyCompiles(formatAttribute!"value"));
    }
    
    void startDoctype(StringType content)
    {
        assert(!insideDTD && !startingTag);
        
        mixin(ifAnyCompiles(expand!"beforeNode"));
        output.put("<!DOCTYPE");
        output.put(content);
        mixin(ifAnyCompiles(expand!"afterDoctypeId"));
        output.put("[");
        insideDTD = true;
        mixin(ifAnyCompiles(expand!"afterNode"));
        mixin(ifCompiles("prettyPrinter.increaseLevel"));
    }
    void closeDoctype()
    {
        assert(insideDTD);
        
        mixin(ifCompiles("prettyPrinter.decreaseLevel"));
        insideDTD = false;
        mixin(ifAnyCompiles(expand!"beforeDTDEnd"));
        output.put("]>");
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    void writeDeclaration(StringType decl, StringType content)
    {
        //assert(insideDTD);
        
        mixin(ifAnyCompiles(expand!"beforeNode"));
        output.put("<!");
        output.put(decl);
        output.put(content);
        output.put(">");
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
}

unittest
{
    import std.array: Appender;
    auto app = Appender!string();
    auto writer = Writer!(string, typeof(app))();
    writer.setSink(&app);
    
    writer.writeXMLDeclaration(10, "utf-8", false);
    assert(app.data == "<?xml version='1.0' encoding='utf-8' standalone='no'?>");

    static assert(isWriter!(typeof(writer)));
}

unittest
{
    import std.array: Appender;
    auto app = Appender!string();
    auto writer = Writer!(string, typeof(app), PrettyPrinters.Indenter)();
    writer.setSink(app);
    
    writer.startElement("elem");
    writer.writeAttribute("attr1", "val1");
    writer.writeAttribute("attr2", "val2");
    writer.writeComment("Wonderful comment");
    writer.startElement("self-closing");
    writer.closeElement("self-closing");
    writer.writeText("Wonderful text");
    writer.writeCDATA("Wonderful cdata");
    writer.writeProcessingInstruction("pi", "it works");
    writer.closeElement("elem");
    
    import std.string: lineSplitter;
    auto splitter = app.data.lineSplitter;
    
    assert(splitter.front == "<elem attr1='val1' attr2='val2'>");
    splitter.popFront;
    assert(splitter.front == "\t<!--Wonderful comment-->");
    splitter.popFront;
    assert(splitter.front == "\t<self-closing/>");
    splitter.popFront;
    assert(splitter.front == "\tWonderful text");
    splitter.popFront;
    assert(splitter.front == "\t<![CDATA[[Wonderful cdata]]>");
    splitter.popFront;
    assert(splitter.front == "\t<?pi it works?>");
    splitter.popFront;
    assert(splitter.front == "</elem>");
    splitter.popFront;
    assert(splitter.empty);
}

/++
+   Writes the contents of a cursor to a writer.
+
+   This method advances the cursor till the end of the document, outputting all
+   nodes using the given writer. The actual work is done inside a fiber, which is
+   then returned. This means that if the methods of the cursor call `Fiber.yield`,
+   this method will not complete its work, but will return a fiber in `HOLD` status,
+   which the user can `call` to advance the work. This is useful if the cursor
+   has to wait for other nodes to be ready (e.g. if the cursor input is generated
+   programmatically).
+/
auto writeCursor(WriterType, CursorType)(auto ref WriterType writer, auto ref CursorType cursor)
{
    alias StringType = WriterType.StringType;
    void inspectOneLevel()
    {
        do
        {
            switch (cursor.getKind) with (XMLKind)
            {
                case DOCUMENT:
                    StringType version_, encoding, standalone;
                    foreach (attr; cursor.getAttributes)
                        if (attr.name == "version")
                            version_ = attr.value;
                        else if (attr.name == "encoding")
                            encoding = attr.value;
                        else if (attr.name == "standalone")
                            standalone = attr.value;
                    writer.writeXMLDeclaration(version_, encoding, standalone);
                    if (cursor.enter)
                    {
                        inspectOneLevel();
                        cursor.exit;
                    }
                    break;
                case DTD_EMPTY:
                case DTD_START:
                    writer.startDoctype(cursor.getAll);
                    if (cursor.enter)
                    {
                        inspectOneLevel();
                        cursor.exit;
                    }
                    writer.closeDoctype();
                    break;
                case ATTLIST_DECL:
                    writer.writeDeclaration("ATTLIST", cursor.getAll);
                    break;
                case ELEMENT_DECL:
                    writer.writeDeclaration("ELEMENT", cursor.getAll);
                    break;
                case ENTITY_DECL:
                    writer.writeDeclaration("ENTITY", cursor.getAll);
                    break;
                case NOTATION_DECL:
                    writer.writeDeclaration("NOTATION", cursor.getAll);
                    break;
                case DECLARATION:
                    writer.writeDeclaration(cursor.getName, cursor.getContent);
                    break;
                case TEXT:
                    writer.writeText(cursor.getContent);
                    break;
                case CDATA:
                    writer.writeCDATA(cursor.getContent);
                    break;
                case COMMENT:
                    writer.writeComment(cursor.getContent);
                    break;
                case PROCESSING_INSTRUCTION:
                    writer.writeProcessingInstruction(cursor.getName, cursor.getContent);
                    break;
                case ELEMENT_START:
                case ELEMENT_EMPTY:
                    writer.startElement(cursor.getName);
                    for (auto attrs = cursor.getAttributes; !attrs.empty; attrs.popFront)
                    {
                        auto attr = attrs.front;
                        writer.writeAttribute(attr.name, attr.value);
                    }
                    if (cursor.enter)
                    {
                        inspectOneLevel();
                        cursor.exit;
                    }
                    writer.closeElement(cursor.getName);
                    break;
                default:
                    break;
                    //assert(0);
            }
        }
        while (cursor.next);
    }
    
    import core.thread: Fiber;
    
    auto fiber = new Fiber(&inspectOneLevel);
    //inspectOneLevel();
    fiber.call;
    return fiber;
}

unittest
{
    import std.array: Appender;
    import std.experimental.xml.parser;
    import std.experimental.xml.cursor;
    
    string xml = 
    "<?xml?>\n" ~
    "<!DOCTYPE ciaone [\n" ~
    "\t<!ELEMENT anything here>\n" ~
    "\t<!ATTLIST no check at all...>\n" ~
    "\t<!NOTATION dunno what to write>\n" ~
    "\t<!ENTITY .....>\n" ~
    "\t<!I_SAID_NO_CHECKS_AT_ALL_BY_DEFAULT>\n" ~
    "]>\n";
    
    auto cursor = chooseParser!xml.cursor;
    cursor.setSource(xml);
    
    auto app = Appender!string();
    auto writer = Writer!(string, typeof(app), PrettyPrinters.Indenter)();
    writer.setSink(app);
        
    auto fiber = writer.writeCursor(cursor);
    assert(fiber.state == fiber.state.TERM);
    
    assert(app.data == xml);
}

/++
+   A writer that validates the input given by the user using a chain of validating
+   cursors.
+/
struct CheckedWriter(WriterType, CursorType = void)
    if (isWriter!(WriterType) && (is(CursorType == void) || (isCursor!CursorType && is(WriterType.StringType == CursorType.StringType))))
{
    import core.thread: Fiber;
    private Fiber fiber;
    private bool startingTag = false;
    
    WriterType writer;
    alias writer this;
    
    alias StringType = WriterType.StringType;
    
    static if (is(CursorType == void))
    {
        struct Cursor
        {
            import std.experimental.xml.cursor: Attribute;
            import std.container.array;
            
            alias StringType = WriterType.StringType;
            
            private StringType name, content;
            private Array!(Attribute!StringType) attrs;
            private XMLKind kind;
            private size_t colon;
            private bool initialized;
            
            void _setName(StringType name)
            {
                import std.experimental.xml.faststrings;
                this.name = name;
                auto i = name.fastIndexOf(':');
                if (i > 0)
                    colon = i;
                else
                    colon = 0;
            }
            void _addAttribute(StringType name, StringType value)
            {
                attrs.insertBack(Attribute!StringType(name, value));
            }
            void _setKind(XMLKind kind)
            {
                this.kind = kind;
                initialized = true;
                attrs.clear;
            }
            void _setContent(StringType content) { this.content = content; }
            
            auto getKind()
            {
                if (!initialized)
                    Fiber.yield;
                    
                return kind;
            }
            auto getName() { return name; }
            auto getPrefix() { return name[0..colon]; }
            auto getContent() { return content; }
            auto getAttributes() { return attrs[]; }
            StringType getLocalName()
            {
                if (colon)
                    return name[colon+1..$];
                else
                    return [];
            }
            
            bool enter()
            {
                if (kind == XMLKind.DOCUMENT)
                {
                    Fiber.yield;
                    return true;
                }
                if (kind != XMLKind.ELEMENT_START)
                    return false;
                    
                Fiber.yield;
                return kind != XMLKind.ELEMENT_END;
            }
            bool next()
            {
                Fiber.yield;
                return kind != XMLKind.ELEMENT_END;
            }
            void exit() {}
            bool atBeginning()
            {
                return !initialized || kind == XMLKind.DOCUMENT;
            }
            bool documentEnd() { return false; }
            
            alias InputType = void*;
            StringType getAll()
            {
                assert(0, "Cannot call getAll on this type of cursor");
            }
            void setSource(InputType)
            {
                assert(0, "Cannot set the source of this type of cursor");
            }
        }
        Cursor cursor;
    }
    else
    {
        CursorType cursor;
    }
    
    void writeXMLDeclaration(Args...)(Args args)
    {
        auto attrs = xmlDeclarationAttributes!StringType(args);
        cursor._setKind(XMLKind.DOCUMENT);
        if (attrs[0])
            cursor._addAttribute("version", attrs[0]);
        if (attrs[1])
            cursor._addAttribute("encoding", attrs[1]);
        if (attrs[2])
            cursor._addAttribute("standalone", attrs[2]);
        fiber.call;
    }
    void writeXMLDeclaration(StringType version_, StringType encoding, StringType standalone)
    {
        cursor._setKind(XMLKind.DOCUMENT);
        if (version_)
            cursor._addAttribute("version", version_);
        if (encoding)
            cursor._addAttribute("encoding", encoding);
        if (standalone)
            cursor._addAttribute("standalone", standalone);
        fiber.call;
    }
    void writeComment(StringType text)
    {
        if (startingTag)
        {
            fiber.call;
            startingTag = false;
        }
        cursor._setKind(XMLKind.COMMENT);
        cursor._setContent(text);
        fiber.call;
    }
    void writeText(StringType text)
    {
        if (startingTag)
        {
            fiber.call;
            startingTag = false;
        }
        cursor._setKind(XMLKind.TEXT);
        cursor._setContent(text);
        fiber.call;
    }
    void writeCDATA(StringType text)
    {
        if (startingTag)
        {
            fiber.call;
            startingTag = false;
        }
        cursor._setKind(XMLKind.CDATA);
        cursor._setContent(text);
        fiber.call;
    }
    void writeProcessingInstruction(StringType target, StringType data)
    {
        if (startingTag)
        {
            fiber.call;
            startingTag = false;
        }
        cursor._setKind(XMLKind.COMMENT);
        cursor._setName(target);
        cursor._setContent(data);
        fiber.call;
    }
    void startElement(StringType tag)
    {
        if (startingTag)
            fiber.call;
            
        startingTag = true;
        cursor._setKind(XMLKind.ELEMENT_START);
        cursor._setName(tag);
    }
    void closeElement(StringType tag)
    {
        if (startingTag)
        {
            fiber.call;
            startingTag = false;
        }
        cursor._setKind(XMLKind.ELEMENT_END);
        cursor._setName(tag);
        fiber.call;
    }
    void writeAttribute(StringType name, StringType value)
    {
        assert(startingTag);
        cursor._addAttribute(name, value);
    }
}

///
template withValidation(alias validationFun, Params...)
{
    import std.traits;
    
    auto withValidation(Writer, Args...)(auto ref Writer writer, auto ref Args args)
        if (isWriter!Writer)
    {
        static if (__traits(isSame, TemplateOf!Writer, CheckedWriter))
        {
            auto cursor = validationFun!Params(typeof(Writer.cursor)(), args);
        }
        else
        {
            auto cursor = validationFun!Params(CheckedWriter!Writer.Cursor(), args);
        }
        
        auto res = CheckedWriter!(Writer, typeof(cursor))();
        res.cursor = cursor;
        res.writer = writer;
        res.fiber = writeCursor(res.writer, res.cursor);
        return res;
    }
}

unittest
{
    import std.array: Appender;
    import std.experimental.xml.validation;
    
    int count = 0;
    
    auto app = Appender!string();
    auto writer =
         Writer!(string, typeof(app), PrettyPrinters.Indenter)()
        .withValidation!checkXMLNames((string s) { count++; }, (string s) { count++; });
    writer.setSink(&app);
    
    writer.writeXMLDeclaration(10, "utf-8", false);
    assert(app.data == "<?xml version='1.0' encoding='utf-8' standalone='no'?>\n");
    
    writer.writeComment("a nice comment");
    writer.startElement("aa;bb");
    writer.writeAttribute(";eh", "foo");
    writer.writeText("a nice text");
    writer.writeCDATA("a nice CDATA");
    writer.closeElement("aabb");
    assert(count == 2);
}