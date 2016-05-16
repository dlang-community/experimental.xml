
import std.array;
import std.ascii : letters, digits, whitespace;
import std.conv;
import std.random : Random, uniform, rndGen;

uint numberOfTests = 5;

ulong minDepth = 1;
ulong maxDepth = 15;

ulong minTagLen = 1;
ulong maxTagLen = 20;
double openClose = 0;

ulong minAttributeNum = 0;
ulong maxAttributeNum = 5;
ulong minAttributeKey = 1;
ulong maxAttributeKey = 20;
ulong minAttributeValue = 0;
ulong maxAttributeValue = 20;

ulong minChilds = 0;
ulong maxChilds = 7;

Random random;

void indent(Out)(Out output, const ulong indent) {
	for(ulong i = 0; i < indent; ++i) {
		output.put(' ');
	}
}

string genString(const ulong minLen, const ulong maxLen) @safe {
	auto ret = appender!string();

	immutable ulong len = uniform(minLen, maxLen, random);
	for(ulong i = 0; i < len; ++i) {
		ret.put(letters[uniform(0, letters.length, random)]);
	}

	return ret.data;
}

string genString(const ulong minLen, const ulong maxLen, const ulong ind) @safe {
	auto ret = appender!string();

	ulong len = uniform(minLen, maxLen, random);
	indent(ret, ind);
	for(ulong i = 0; i < len; ++i) {
		if(i % (80 - ind) == 0) {
			ret.put("\n");
			indent(ret, ind);
		}
		ret.put(letters[uniform(0, letters.length, random)]);
	}
	ret.put("\n");

	return ret.data;
}

void genAttributes(Out)(Out output) {
	immutable ulong numAttribute = uniform(minAttributeNum, maxAttributeNum, random);
	for(ulong it = 0; it < numAttribute; ++it) {
		if(it > 0u) {
			output.put(" ");	
		}
		
		output.put(genString(minAttributeKey, maxAttributeKey));
		output.put("=\"");
		output.put(genString(minAttributeValue, maxAttributeValue));
		output.put("\"");
	}
}

void genTag(Out)(Out output, ulong depth) {
	immutable auto tag = genString(minTagLen, maxTagLen); 
	indent(output, depth);
	output.put("<");
	output.put(tag);
	output.put(' ');
	genAttributes(output);
	immutable bool openCloseT = uniform(0.0,1.0,random) < openClose;
	if (openCloseT) {
		output.put("/>\n");
		return;
	} else {
		output.put(">\n");
	}

	immutable ulong numChilds = uniform(minChilds, maxChilds, random);
	immutable ulong nd = uniform(minDepth, maxDepth, random);
	for (ulong childs = 0; childs < numChilds; ++childs) {
		if (nd > depth) {
			genTag(output, depth+1);
		}
	}

	indent(output, depth);
	output.put("</");
	output.put(tag);
	output.put(">\n");
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
        genTag(f.lockingTextWriter(), 0u);
    }
}