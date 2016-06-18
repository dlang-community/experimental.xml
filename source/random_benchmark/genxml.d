/*
*    Copyright Lodovico Giaretta and Robert Schadek 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

import std.array;
import std.ascii : letters, digits, whitespace;
import std.conv;
import std.random : Random, uniform, rndGen;

uint numberOfTests = 5;

struct GenXmlConfig
{
    string name;
    
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
    
    string prettyPrint(uint ind = 0)
    {
        auto result = appender!string();
        
        void putRange(string name, ulong start, ulong stop)
        {
            indent(result, ind);
            result.put(name);
            string value = "[" ~ to!string(start) ~ ".." ~ to!string(stop) ~ "]";
            indent(result, 44 - name.length - value.length);
            result.put(value);
            result.put("\n");
        }
        void putProbability(string name, double prob)
        {
            indent(result, ind);
            result.put(name);
            string value = to!string(to!int(prob * 100)) ~ "%";
            indent(result, 44 - name.length - value.length);
            result.put(value);
            result.put("\n");
        }
        
        putRange("tree depth:", minDepth, maxDepth);
        putRange("number of childs:", minChilds, maxChilds);
        putRange("number of attributes", minAttributeNum, maxAttributeNum);
        putProbability("self-closing tag percentage:", openClose);
        putProbability("text node probability:", textNodes);
        putProbability("CDATA section probability:", cdataNodes);
        putProbability("processing instruction probability:", piNodes);
        putProbability("comment node probability:", commentNodes);
        putProbability("empty lines probability:", emptyLines);
        putRange("tag length: ", minTagLen, maxTagLen);
        putRange("attribute key length:", minAttributeKey, maxAttributeKey);
        putRange("attribute value length:", minAttributeValue, maxAttributeValue);
        putRange("text/CDATA/comment length:", minTextLen, maxTextLen);
        putRange("random spaces range:", minSpaceLen, maxSpaceLen);
        
        return result.data;
    }
}

struct FileStats
{
    ulong elements;
    ulong textNodes;
    ulong cdataNodes;
    ulong processingInstructions;
    ulong comments;
    ulong attributes;
    ulong textChars;
    ulong spaces;
}

Random random;

void indent(Out)(Out output, const ulong indent) {
	for(ulong i = 0; i < indent; ++i) {
		output.put(' ');
	}
}
void indent(Out)(Out output, const ulong indent, ref FileStats stats) {
	for(ulong i = 0; i < indent; ++i) {
		output.put(' ');
	}
    stats.spaces += indent;
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

string genSpace(GenXmlConfig config, ref FileStats stats, ulong min = 0) @safe
{
    auto ret = appender!string();
    
    immutable ulong len = uniform(config.minSpaceLen, config.maxSpaceLen, random) + min;
    for (ulong i = 0; i < len ; i++)
        ret.put(' ');
        
    stats.spaces += len;    
    return ret.data;
}

string genNewlines(GenXmlConfig config, ref FileStats stats) @safe
{
    auto ret = appender!string();
    
    ret.put('\n');
    ulong count = 1;
    while(uniform(0.0, 1.0, random) < config.emptyLines)
    {
        ret.put('\n');
        count++;
    }
    
    stats.spaces += count;
    return ret.data;
}

void genAttributes(Out)(Out output, GenXmlConfig config, ref FileStats stats)
{
    import std.container.rbtree;

	immutable ulong numAttribute = uniform(config.minAttributeNum, config.maxAttributeNum, random);
    auto set = redBlackTree!string();
	for(ulong it = 0; it < numAttribute; ++it)
    {
        output.put(genSpace(config, stats, 1));
        string s;
        do
        {
            s = genString(config.minAttributeKey, config.maxAttributeKey);
        } while (s in set);
        set.insert(s);
		output.put(s);
        output.put(genSpace(config, stats));
		output.put('=');
        output.put(genSpace(config, stats));
		output.put('"');
		output.put(genString(config.minAttributeValue, config.maxAttributeValue));
		output.put('"');
	}
    stats.attributes += numAttribute;
}

void genChild(Out)(Out output, ulong depth, GenXmlConfig config, ref FileStats stats)
{
    if (depth < config.minDepth)
        genTag(output, depth, config, stats);
    else
    {
        auto what = uniform(0.0, 1.0, random);
        if (what < config.textNodes)
            genText(output, depth, config, stats);
        else if (what < config.textNodes + config.cdataNodes)
            genCDATA(output, depth, config, stats);
        else if (what < config.textNodes + config.cdataNodes + config.piNodes)
            genPI(output, depth, config, stats);
        else if (what < config.textNodes + config.cdataNodes + config.piNodes + config.commentNodes)
            genComment(output, depth, config, stats);
        else
            genTag(output, depth, config, stats);
    }
}

void genLeaf(Out)(Out output, ulong depth, GenXmlConfig config, ref FileStats stats)
{
    auto what = uniform(0.0, config.textNodes + config.cdataNodes + config.piNodes + config.commentNodes);
    if (what < config.textNodes)
        genText(output, depth, config, stats);
    else if (what < config.textNodes + config.cdataNodes)
        genCDATA(output, depth, config, stats);
    else if (what < config.textNodes + config.cdataNodes + config.piNodes)
        genPI(output, depth, config, stats);
    else
        genComment(output, depth, config, stats);
}

immutable auto textChars = letters ~ digits ~ " \t\n";

void genText(Out)(Out output, ulong depth, GenXmlConfig config, ref FileStats stats)
{
    indent(output, depth, stats);
    auto str = genString(config.minTextLen, config.maxTextLen, textChars, depth);
    output.put(str);
    output.put(genNewlines(config, stats));
    stats.textNodes++;
}

void genCDATA(Out)(Out output, ulong depth, GenXmlConfig config, ref FileStats stats)
{
    indent(output, depth, stats);
    output.put("<!CDATA[[");
    auto str = genString(config.minTextLen, config.maxTextLen, textChars, depth);
    output.put(str);
    output.put("]]>");
    output.put(genNewlines(config, stats));
    stats.textChars += str.length;
    stats.cdataNodes++;
}

void genPI(Out)(Out output, ulong depth, GenXmlConfig config, ref FileStats stats)
{
    immutable auto tag = genString(config.minTagLen, config.maxTagLen);
	indent(output, depth, stats);
	output.put("<?");
	output.put(tag);
	genAttributes(output, config, stats);
    output.put(genSpace(config, stats));
    output.put("?>");
    output.put(genNewlines(config, stats));
    stats.processingInstructions++;
}

void genComment(Out)(Out output, ulong depth, GenXmlConfig config, ref FileStats stats)
{
    indent(output, depth, stats);
    output.put("<!--");
    auto str = genString(config.minTextLen, config.maxTextLen, textChars, depth);
    output.put(str);
    output.put("-->");
    stats.textChars += str.length;
    output.put(genNewlines(config, stats));
    stats.comments++;
}

void genTag(Out)(Out output, ulong depth, GenXmlConfig config, ref FileStats stats)
{
	immutable auto tag = genString(config.minTagLen, config.maxTagLen);
	indent(output, depth, stats);
	output.put("<");
	output.put(tag);
	genAttributes(output, config, stats);
    output.put(genSpace(config, stats));
	if (uniform(0.0, 1.0, random) < config.openClose)
    {
		output.put("/>");
        output.put(genNewlines(config, stats));
		return;
	}
    output.put(">");
    output.put(genNewlines(config, stats));

	immutable ulong numChilds = uniform(1, config.maxChilds, random);
	immutable ulong nd = uniform(config.minDepth, config.maxDepth, random);
	for (ulong childs = 0; childs < numChilds; ++childs)
		if (nd > depth)
			genChild(output, depth + 1, config, stats);
        else
            genLeaf(output, depth + 1, config, stats);

	indent(output, depth, stats);
	output.put("</");
	output.put(tag);
    output.put(genSpace(config, stats));
	output.put(">");
    output.put(genNewlines(config, stats));
    stats.elements++;
}

auto genDocument(Out)(Out output, GenXmlConfig config)
{
    FileStats stats;
    output.put("<?xml version=\"1.1\" ?>");
    output.put(genNewlines(config, stats));
    genTag(output, 0, config, stats);
    return stats;
}