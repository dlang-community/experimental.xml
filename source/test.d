/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module test;

import std.experimental.xml;

import std.encoding: transcode, Latin1String;
import std.file: read, readText;
import std.functional: toDelegate;
import std.path;
import std.stdio: write, writeln;
import std.utf: UTFException;

auto indexes = 
[
    "tests/sun/sun-valid.xml",
    "tests/sun/sun-error.xml",
    "tests/sun/sun-invalid.xml",
    "tests/sun/sun-not-wf.xml",
    "tests/xmltest/xmltest.xml",
    "tests/oasis/oasis.xml",
    "tests/ibm/ibm_oasis_invalid.xml",
    "tests/ibm/ibm_oasis_not-wf.xml",
    "tests/ibm/ibm_oasis_valid.xml",
    "tests/ibm/xml-1.1/ibm_invalid.xml",
    "tests/ibm/xml-1.1/ibm_not-wf.xml",
    "tests/ibm/xml-1.1/ibm_valid.xml",
    "tests/eduni/errata-2e/errata2e.xml",
    "tests/eduni/xml-1.1/xml11.xml",
    "tests/eduni/namespaces/1.0/rmt-ns10.xml",
    "tests/eduni/namespaces/1.1/rmt-ns11.xml",
    "tests/eduni/errata-3e/errata3e.xml",
    "tests/eduni/namespaces/errata-1e/errata1e.xml",
    "tests/eduni/errata-4e/errata4e.xml",
    "tests/eduni/misc/ht-bh.xml"
];

struct Results
{
    int[string] totals;
    int[string] wrong;
    
    static Results opCall()
    {
        Results result;
        result.totals = ["valid": 0, "linted": 0, "invalid": 0, "not-wf": 0, "error": 0, "skipped": 0];
        result.wrong = ["valid": 0, "linted":0, "invalid": 0, "not-wf": 0, "error": 0];
        return result;
    }
    
    void opOpAssign(string op)(Results other)
    {
        static if (op == "+")
        {
            foreach (key, val; other.totals)
                totals[key] += val;
            foreach (key, val; other.wrong)
                wrong[key] += val;
        }
        else
        {
            static assert(0);
        }
    }
}

void writeIndent(int depth)
{
    for (int i = 0; i < depth; i++)
        write("\t");
}

void printResults(Results results, int depth)
{
    writeIndent(depth);
    writeln("== RESULTS ==");
    writeIndent(depth);
    writeln(results.wrong["valid"], " valid inputs rejected out of ", results.totals["valid"], " total.");
    writeIndent(depth);
    writeln(results.wrong["linted"], " wrong outputs out of ", results.totals["linted"], " total written files.");
    writeIndent(depth);
    writeln(results.wrong["invalid"], " invalid inputs accepted out of ", results.totals["invalid"], " total.");
    writeIndent(depth);
    writeln(results.wrong["not-wf"], " ill-formed inputs accepted out of ", results.totals["not-wf"], " total.");
    writeIndent(depth);
    writeln(results.wrong["error"], " erroneous inputs accepted out of ", results.totals["error"], " total.");
    writeIndent(depth);
    writeln(results.totals["skipped"], " inputs skipped because of unsupported features.");
}

Results handleTestcases(T)(string directory, ref T cursor, int depth)
{
    auto results = Results();
    do
    {
        if (cursor.getName() == "TESTCASES")
        {
            writeIndent(depth);
            write("TESTCASES");
            foreach (att; cursor.getAttributes())
                if (att.name == "PROFILE")
                    write(" -- ", att.value);
            writeln();
            
            if (cursor.enter())
            {
                results += handleTestcases(directory, cursor, depth + 1);
                cursor.exit();
            }
        }
        else if (cursor.getName() == "TEST")
        {
            results += handleTest(directory, cursor, depth);
        }
    }
    while (cursor.next());
    printResults(results, depth);
    writeln();
    return results;
}

Results handleTest(T)(string directory, ref T cursor, int depth)
{
    auto result = Results();
    
    string file, kind;
    foreach (att; cursor.getAttributes())
        if (att.name == "ENTITIES" && att.value != "none")
        {
            result.totals["skipped"]++;
            return result;
        }
        else if (att.name == "TYPE" && att.value in result.totals)
            kind = att.value;
        else if (att.name == "URI")
            file = att.value;
    
    result.totals[kind]++;
    
    bool passed = true, linted = false, linted_ok = false;
    try
    {
        linted_ok = parseFile(directory ~ dirSeparator ~ file, linted);
    }
    catch (MyException err)
    {
        passed = false;
    }
    if (passed && kind != "valid")
    {
        writeIndent(depth);
        write("FAILED: accepted ");
        result.wrong[kind]++;
        switch (kind)
        {
            case "invalid":
                write("invalid ");
                break;
            case "not-wf":
                write("ill-formed ");
                break;
            case "error":
                write("erroneous ");
                break;
            default:
                assert(0);
        }
        writeln("file ", file);
    }
    else if (!passed && kind == "valid")
    {
        writeIndent(depth);
        result.wrong["valid"]++;
        writeln("FAILED: rejected valid file ", file);
    }
    else
    {
        writeIndent(depth);
        writeln("OK: ", file);
        if (passed && linted)
        {
            result.totals["linted"]++;
            if (!linted_ok)
            {
                result.wrong["linted"]++;
                writeIndent(depth + 1);
                writeln("[WRONG DIFF]");
            }
        }
    }
    
    return result;
}

class MyException: Exception
{
    this(string msg)
    {
        super(msg);
    }
}

// callback used to ignore missing xml declaration, while throwing on invalid attributes
void uselessCallback(CursorError err)
{
    if (err != CursorError.MISSING_XML_DECLARATION)
        throw new MyException("AAAAHHHHH");
}

/++
+ Most tests are currently not working for the following reasons:
+ - We don't have any validation, so we accept all files that seem well formed;
+/
void main()
{
    auto cursor = 
         chooseLexer!string
        .parse
        .cursor(&uselessCallback); // If an index is not well-formed, just tell us but continue parsing
    
    auto results = Results();
    foreach (i, index; indexes)
    {
        writeln(i, " -- ", index);
        
        cursor.setSource(readText(index));
        cursor.enter();
        
        results += handleTestcases(dirName(index), cursor, 1);
    }
    
    printResults(results, 0);
    writeln();
}

bool parseFile(string filename, ref bool lint)
{
    void inspectOneLevel(T)(ref T cursor)
    {
        do
        {
            if (cursor.enter)
            {
                inspectOneLevel(cursor);
                cursor.exit();
            }
        }
        while (cursor.next());
    }

    string text;
    try
    {
        text = readText(filename);
    }
    catch (UTFException)
    {
        try
        {
            auto raw = read(filename);
            auto bytes = cast(ubyte[])raw;
        
            if(bytes.length > 1 && bytes[0] == 0xFF && bytes[1] == 0xFE)
            {
                auto shorts = cast(ushort[])raw;
                transcode(cast(wstring)(shorts[1..$]), text);
            }
            else
                transcode(cast(Latin1String)raw, text);
        }
        catch(Throwable)
        {
            throw new MyException("AAAAHHHHH");
        }
    }
    
    auto cursor = 
         chooseParser!text(() { throw new MyException("AAAAHHHHH"); })
        .cursor(&uselessCallback); // lots of tests do not have an xml declaration
    
    cursor.setSource(text);
    
    lint = false;
    foreach (attr; cursor.getAttributes)
        if (attr.name == "version" && attr.value == "1.0")
            lint = true;
    
    inspectOneLevel(cursor);
    
    if (lint)
    {
        import std.process, std.stdio, std.array;
        import std.experimental.xml.writer;
    
        lint = false;
        bool result = false;
        auto xmllint = executeShell("xmllint --pretty 2 --c14n11 " ~ filename ~ " > linted_input.xml");
        if (xmllint.status == 0)
        {
            {
                cursor.setSource(text);
                auto file = File("output.xml", "w");
                auto ltw = file.lockingTextWriter;
                auto writer = Writer!(string, typeof(ltw))();
                
                writer.setSink(ltw);
                writer.writeCursor(cursor);
            }
            
            xmllint = executeShell("xmllint --pretty 2 --c14n11 output.xml > linted_output.xml");
            if (xmllint.status == 0)
            {
                lint = true;
                auto diff = executeShell("diff linted_input.xml linted_output.xml");
                result = diff.status == 0;
            }
        }
        executeShell("rm -f linted_output.xml linted_input.xml output.xml");
        return result;
    }
    return false;
}
