/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module benchmark;

import std.experimental.xml;

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
    return dirEntries("benchmark", SpanMode.shallow);
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
    writeln("\n=== PARSER PERFORMANCE ===");
    
    writeln("SliceLexer:");
    performTests((data) {
        auto parser = Parser!(SliceLexer!(string, void delegate()), void delegate())();
        parser.setSource(data);
        foreach (e; parser)
        {
            doNotOptimize(e);
        }
    });
    
    writeln("RangeLexer:");
    performTests((data) {
        auto parser = Parser!(RangeLexer!(string, void delegate()), void delegate())();
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
            foreach(attr; cursor.getAttributes)
                doNotOptimize(attr);
                
            if (cursor.enter)
            {
                inspectOneLevel(cursor);
                cursor.exit();
            }
        }
        while (cursor.next());
    }
    
    writeln("SliceLexer:");
    performTests((data) {
        auto cursor = Cursor!(Parser!(SliceLexer!(string, void delegate()), void delegate()))();
        cursor.setErrorHandler(delegate void(CursorError err) { return; });
        cursor.setSource(data);
        inspectOneLevel(cursor);
    });
    
    writeln("RangeLexer:");
    performTests((data) {
        auto cursor = Cursor!(Parser!(RangeLexer!(string, void delegate()), void delegate()))();
        cursor.setErrorHandler(delegate void(CursorError err) { return; });
        cursor.setSource(data);
        inspectOneLevel(cursor);
    });
}