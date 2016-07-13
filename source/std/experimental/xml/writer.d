
module std.experimental.xml.writer;

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

struct PrettyPrinters
{
    struct Minimalizer(StringType)
    {
        // minimum requirements needed for correctness
        enum StringType beforeAttributeName = " ";
        enum StringType betweenPITargetData = " ";
    }
    struct Indenter(StringType)
    {
        // inherit minimum requirements 
        Minimalizer!StringType minimalizer;
        alias minimalizer this;
    
        enum StringType afterNode = "\n";
        enum StringType attributeDelimiter = "'";
        
        uint indentation;
        enum StringType tab = "\t";
        void increaseLevel() { indentation++; }
        void decreaseLevel() { indentation--; }
        
        void beforeNode(Out)(ref Out output)
        {
            foreach (i; 0..indentation)
                output.put(tab);
        }
    }
}

struct Writer(StringType, alias OutRange, alias PrettyPrinter = PrettyPrinters.Minimalizer)
{
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
    
    bool startingTag = false;
    
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
    
    void writeXMLDeclaration(Args...)(Args args)
    {
        static assert(Args.length <= 3, "Too many arguments for xml declaration");
        
        output.put("<?xml");
        
        // version specification
        static if (is(Args[0] == int))
        {
            auto versionNum = args[0];
            auto args1 = args[1..$];
        }
        else
        {
            enum versionNum = 11;
            auto args1 = args;
        }
        StringType versionString = versionNum == 10 ? "1.0" : (versionNum == 11 ? "1.1" : "");
        assert(versionString != "", "Invalid xml version specified");
        
        mixin(ifAnyCompiles(expand!"beforeAttributeName"));
        output.put("version");
        mixin(ifAnyCompiles(expand!"afterAttributeName"));
        output.put("=");
        mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
        mixin(ifAnyCompiles(formatAttribute!"versionString"));
        
        // encoding specification
        static if (is(typeof(args1[0]) == StringType))
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output.put("encoding");
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output.put("=");
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"args1[0]"));
            auto args2 = args1[1..$];
        }
        else args2 = args1;
        
        // standalone specification
        static if (is(typeof(args2[0]) == bool))
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output.put("standalone");
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output.put("=");
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"(args2[0] ? \"yes\" : \"no\")"));
            auto args3 = args2[1..$];
        }
        else args3 = args2;
        
        // catch other erroneous parameters
        static assert(typeof(args3).length == 0, "Unrecognized attribute type for xml declaration: " ~ typeof(args3[0]).stringof);
        
        output.put("?>");
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    
    void writeComment(StringType comment)
    {
        if (startingTag) closeStartingTag;
    
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
    void writeText(StringType text)
    {
        if (startingTag) closeStartingTag;
    
        mixin(ifAnyCompiles(expand!"beforeNode"));
        mixin(ifCompilesElse(
            "prettyPrinter.formatText(output, comment)",
            "output.put(text)"
        ));
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    void writeCDATA(StringType cdata)
    {
        if (startingTag) closeStartingTag;
    
        mixin(ifAnyCompiles(expand!"beforeNode"));
        output.put("<![CDATA[[");
        output.put(cdata);
        output.put("]]>");
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    void writeProcessingInstruction(StringType target, StringType data)
    {
        if (startingTag) closeStartingTag;
    
        mixin(ifAnyCompiles(expand!"beforeNode"));
        output.put("<?");
        output.put(target);
        mixin(ifAnyCompiles(expand!"betweenPITargetData"));
        output.put(data);
        
        mixin(ifAnyCompiles(expand!"beforePIEnd"));
        output.put("?>");
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    
    private void closeStartingTag()
    {
        mixin(ifAnyCompiles(expand!"beforeElementEnd"));
        output.put(">");
        mixin(ifAnyCompiles(expand!"afterNode"));
        startingTag = false;
        mixin(ifCompiles("prettyPrinter.increaseLevel"));
    }
    void startElement(StringType tagName)
    {
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
        }
        else
        {
            mixin(ifCompiles("prettyPrinter.decreaseLevel"));
            mixin(ifAnyCompiles(expand!"beforeNode"));
            output.put("</");
            output.put(tagName);
            mixin(ifAnyCompiles(expand!"beforeElementEnd"));
            output.put(">");
        }
        mixin(ifAnyCompiles(expand!"afterNode"));
        startingTag = false;
    }
    void writeAttribute(StringType name, StringType value)
    {
        debug assert(startingTag, "Cannot write attribute outside element start");
        
        mixin(ifAnyCompiles(expand!"beforeAttributeName"));
        output.put(name);
        mixin(ifAnyCompiles(expand!"afterAttributeName"));
        output.put("=");
        mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
        mixin(ifAnyCompiles(formatAttribute!"value"));
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