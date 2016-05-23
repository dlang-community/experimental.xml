
module random_benchmark;

import genxml;

import std.experimental.xml.lexers;
import std.experimental.xml.parser;
import std.experimental.xml.cursor;

import std.stdio;
import std.file;
import std.conv;

void doNotOptimize(T)(auto ref T result)
{
    import std.process: thisProcessID;
    if (thisProcessID == 1)
        writeln(result);
}

auto getTestFiles()
{
    import std.algorithm: count;
    import std.array: array;
    if (!exists("random-benchmark") || dirEntries("random-benchmark", SpanMode.shallow).count == 0)
    {
        writeln("Generating test files...");
        createRandomBenchmarks("random-benchmark");
    }
    return dirEntries("random-benchmark", SpanMode.shallow);
}

void performTests(void delegate(string) dg)
{
    import core.time;
    auto i = 1;
    foreach(string test; getTestFiles)
    {
        auto data = readText(test);
        MonoTime before = MonoTime.currTime;
        dg(data);
        MonoTime after = MonoTime.currTime;
        Duration elapsed = after - before;
        writeln("test ", i++,": \t", elapsed, "\t(", data.length, " characters)");
    }
}

void main()
{
    getTestFiles;
    writeln("\n=== PARSER PERFORMANCE ===");
    
    writeln("SliceLexer:");
    performTests((data) {
        auto parser = Parser!(SliceLexer!string)();
        parser.setSource(data);
        foreach (e; parser)
        {
            doNotOptimize(e);
        }
    });
    
    writeln("RangeLexer:");
    performTests((data) {
        auto parser = Parser!(RangeLexer!string)();
        parser.setSource(data);
        foreach (e; parser)
        {
            doNotOptimize(e);
        }
    });
    
    writeln("\n=== CURSOR PERFORMANCE ===");
    
    void inspectOneLevel(T)(ref T cursor)
    {
        do
        {
            doNotOptimize(cursor.getAttributes());
            if (cursor.hasChildren())
            {
                cursor.enter();
                inspectOneLevel(cursor);
                cursor.exit();
            }
        }
        while (cursor.next());
    }
    
    writeln("SliceLexer:");
    performTests((data) {
        auto cursor = XMLCursor!(Parser!(SliceLexer!string))();
        cursor.setErrorHandler(delegate void(ref typeof(cursor) cur, typeof(cursor).Error err) { return; });
        cursor.setSource(data);
        inspectOneLevel(cursor);
    });
    
    writeln("RangeLexer:");
    performTests((data) {
        auto cursor = XMLCursor!(Parser!(RangeLexer!string))();
        cursor.setErrorHandler(delegate void(ref typeof(cursor) cur, typeof(cursor).Error err) { return; });
        cursor.setSource(data);
        inspectOneLevel(cursor);
    });
}