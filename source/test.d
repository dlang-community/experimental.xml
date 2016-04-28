
module test;

import std.experimental.xml.lexers;
import std.experimental.xml.parser;
import std.experimental.xml.cursor;

import std.encoding: transcode, Latin1String;
import std.file: read, readText;
import std.path;
import std.stdio: write, writeln;
import std.utf: UTFException;

auto indexes = 
[
    "tests/eduni/xml-1.1/xml11.xml",
];

/++
+ Most tests are currently not working for two reasons:
+ 1) We don't have any validation, so we accept all files that seem well formed;
+ 2) std.file.readText rejects files with encoding iso-8859.
+/
void main()
{
    auto cursor = XMLCursor!(Parser!(SliceLexer!string))();
    
    int failed;
    int total;
    foreach (i, index; indexes)
    {
        cursor.setSource(readText(index));
        cursor.enter();
        
        if (cursor.getName() != "TESTCASES")
            continue;
            
        write(i);
        foreach (att; cursor.getAttributes())
            if (att[1] == "PROFILE")
                write(" -- ", att[2]);
        writeln(" -- ", index);
        
        cursor.enter();
        L: do
        {
            bool positive = true;
            string file;
            foreach (att; cursor.getAttributes())
                if (att[1] == "ENTITIES" && att[2] != "none")
                    continue L;
                else if (att[1] == "TYPE" && att[2] == "not-wf")
                    positive = false;
                else if(att[1] == "URI")
                    file = att[2];
            
            writeln("\t", file);
            
            total++;
            bool passed = true;
            Throwable error;
            try
            {
                parseFile(dirName(index) ~ dirSeparator ~ file);
            }
            catch (Throwable err)
            {
                passed = false;
                error = err;
            }
            if(passed != positive)
            {
                failed++;
                writeln("  == ERROR ==  ");
                if (!passed)
                {
                    writeln(error.info);
                    writeln(error);
                }
                writeln("File ", file, " should", positive?"":" not", " be accepted!");
                cursor.enter();
                writeln(cursor.getText());
                cursor.exit();
            }
        }
        while (cursor.next());
        cursor.exit();
    }
    
    writeln("  == RESULTS ==  ");
    writeln(failed, " tests failed out of ", total, " total.");
}

void parseFile(string filename)
{
    void inspectOneLevel(T)(ref T cursor)
    {
        do
        {
            if (cursor.hasChildren())
            {
                cursor.enter();
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
    catch(UTFException)
    {
        auto raw = read(filename);
        transcode(cast(Latin1String)raw, text);
    }
    
    auto cursor = XMLCursor!(Parser!(SliceLexer!string))();
    cursor.setSource(text);
    inspectOneLevel(cursor);
}
