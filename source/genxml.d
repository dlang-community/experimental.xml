
import std.array;
import std.ascii : letters, digits, whitespace;
import std.conv;
import std.random : Random, uniform, rndGen;

uint numberOfTests = 5;

struct GenXmlConfig
{
    // tweak these for file size
    ulong minDepth;
    ulong maxDepth;
    ulong minChilds;
    ulong maxChilds;
    ulong minAttributeNum;
    ulong maxAttributeNum;

    // probabilities of nodes;
    double openClose = 0.01;
    double textNodes = 0.1;
    double cdataNodes = 0.01;
    double piNodes = 0.01;
    double commentNodes = 0.01;
    double emptyLines = 0.01;
    
    // sizes of texts;
    ulong minTagLen = 3;
    ulong maxTagLen = 15;
    ulong minAttributeKey = 2;
    ulong maxAttributeKey = 15;
    ulong minAttributeValue = 0;
    ulong maxAttributeValue = 20;
    ulong minTextLen = 5;
    ulong maxTextLen = 30;
    ulong minSpaceLen = 0;
    ulong maxSpaceLen = 1;
}

GenXmlConfig M100 = { minDepth:         6,
                      maxDepth:        14,
                      minChilds:        3,
                      maxChilds:        9,
                      minAttributeNum:  0,
                      maxAttributeNum:  5};

Random random;

void indent(Out)(Out output, const ulong indent) {
	for(ulong i = 0; i < indent; ++i) {
		output.put(' ');
	}
}

string genString(const ulong minLen, const ulong maxLen, const char[] source = letters, const ulong ind = 0) @safe
{
	auto ret = appender!string();
	
    immutable ulong len = uniform(minLen, maxLen, random);
	for (ulong i = 0; i < len; ++i)
    {
		auto ch = source[uniform(0, source.length, random)];
        ret.put(ch);
        if (ch == '\n')
            indent(ret, ind);
    }

	return ret.data;
}

string genSpace(GenXmlConfig config, ulong min = 0) @safe
{
    auto ret = appender!string();
    
    immutable ulong len = uniform(config.minSpaceLen, config.maxSpaceLen, random) + min;
    for (ulong i = 0; i < len ; i++)
        ret.put(' ');
        
    return ret.data;
}

string genNewlines(GenXmlConfig config) @safe
{
    auto ret = appender!string();
    
    ret.put('\n');
    while(uniform(0.0, 1.0, random) < config.emptyLines)
        ret.put('\n');
    
    return ret.data;
}

void genAttributes(Out)(Out output, GenXmlConfig config)
{
    import std.container.rbtree;

	immutable ulong numAttribute = uniform(config.minAttributeNum, config.maxAttributeNum, random);
    auto set = redBlackTree!string();
	for(ulong it = 0; it < numAttribute; ++it)
    {
        output.put(genSpace(config, 1));
        string s;
        do
        {
            s = genString(config.minAttributeKey, config.maxAttributeKey);
        } while (s in set);
        set.insert(s);
		output.put(s);
        output.put(genSpace(config));
		output.put('=');
        output.put(genSpace(config));
		output.put('"');
		output.put(genString(config.minAttributeValue, config.maxAttributeValue));
		output.put('"');
	}
}

void genChild(Out)(Out output, ulong depth, GenXmlConfig config)
{
    if (depth < config.minDepth)
        genTag(output, depth, config);
    else
    {
        auto what = uniform(0.0, 1.0, random);
        if (what < config.textNodes)
            genText(output, depth, config);
        else if (what < config.textNodes + config.cdataNodes)
            genCDATA(output, depth, config);
        else if (what < config.textNodes + config.cdataNodes + config.piNodes)
            genPI(output, depth, config);
        else if (what < config.textNodes + config.cdataNodes + config.piNodes + config.commentNodes)
            genComment(output, depth, config);
        else
            genTag(output, depth, config);
    }
}

void genLeaf(Out)(Out output, ulong depth, GenXmlConfig config)
{
    auto what = uniform(0.0, config.textNodes + config.cdataNodes + config.piNodes + config.commentNodes);
    if (what < config.textNodes)
        genText(output, depth, config);
    else if (what < config.textNodes + config.cdataNodes)
        genCDATA(output, depth, config);
    else if (what < config.textNodes + config.cdataNodes + config.piNodes)
        genPI(output, depth, config);
    else
        genComment(output, depth, config);
}

immutable auto textChars = letters ~ digits ~ " \t\n";

void genText(Out)(Out output, ulong depth, GenXmlConfig config)
{
    indent(output, depth);
    output.put(genString(config.minTextLen, config.maxTextLen, textChars, depth));
    output.put(genNewlines(config));
}

void genCDATA(Out)(Out output, ulong depth, GenXmlConfig config)
{
    indent(output, depth);
    output.put("<!CDATA[[");
    output.put(genString(config.minTextLen, config.maxTextLen, textChars, depth));
    output.put("]]>");
    output.put(genNewlines(config));
}

void genPI(Out)(Out output, ulong depth, GenXmlConfig config)
{
    immutable auto tag = genString(config.minTagLen, config.maxTagLen);
	indent(output, depth);
	output.put("<?");
	output.put(tag);
	genAttributes(output, config);
    output.put(genSpace(config));
    output.put("?>");
    output.put(genNewlines(config));
}

void genComment(Out)(Out output, ulong depth, GenXmlConfig config)
{
    indent(output, depth);
    output.put("<!--");
    output.put(genString(config.minTextLen, config.maxTextLen, textChars, depth));
    output.put("-->");
    output.put(genNewlines(config));
}

void genTag(Out)(Out output, ulong depth, GenXmlConfig config)
{
	immutable auto tag = genString(config.minTagLen, config.maxTagLen);
	indent(output, depth);
	output.put("<");
	output.put(tag);
	genAttributes(output, config);
    output.put(genSpace(config));
	if (uniform(0.0, 1.0, random) < config.openClose)
    {
		output.put("/>");
        output.put(genNewlines(config));
		return;
	}
    output.put(">");
    output.put(genNewlines(config));

	immutable ulong numChilds = uniform(1, config.maxChilds, random);
	immutable ulong nd = uniform(config.minDepth, config.maxDepth, random);
	for (ulong childs = 0; childs < numChilds; ++childs)
		if (nd > depth)
			genChild(output, depth + 1, config);
        else
            genLeaf(output, depth + 1, config);

	indent(output, depth);
	output.put("</");
	output.put(tag);
    output.put(genSpace(config));
	output.put(">");
    output.put(genNewlines(config));
}

void genDocument(Out)(Out output, GenXmlConfig config)
{
    output.put("<?xml version=\"1.1\" ?>");
    output.put(genNewlines(config));
    genTag(output, 0, config);
}

void createRandomBenchmarks(string dir)
{
    import std.file: buildPath, exists, mkdir;
    if(!exists(dir))
        mkdir(dir);

    import std.stdio: File;
    random = rndGen;
    foreach (i; 0..numberOfTests)
    {
        auto f = File(buildPath(dir, "test" ~ to!string(i) ~ ".xml"), "w");
        genDocument(f.lockingTextWriter(), M100);
    }
}