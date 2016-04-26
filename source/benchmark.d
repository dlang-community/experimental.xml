
module benchmark;

import std.experimental.xml.lexers;
import std.experimental.xml.parser;
import std.experimental.xml.cursor;

import std.stdio;
import std.file;
import std.conv;
import core.time;

immutable int tests = 4;

void main()
{
    writeln("\n=== PARSER PERFORMANCE ===");
    {
        writeln("SliceLexer:");
        auto parser = Parser!(SliceLexer!string)();
        for (int i = 0; i < tests; i++)
        {
            auto data = readText("benchmark/test_" ~ to!string(i) ~ ".xml");
            MonoTime before = MonoTime.currTime;
            parser.setSource(data);
            foreach (e; parser)
            {
            }
            MonoTime after = MonoTime.currTime;
            Duration elapsed = after - before;
            writeln("test ", i,": \t", elapsed, "\t(", data.length, " characters)");
        }
    }
    {
        writeln("RangeLexer:");
        auto parser = Parser!(RangeLexer!string)();
        for (int i = 0; i < tests; i++)
        {
            auto data = readText("benchmark/test_" ~ to!string(i) ~ ".xml");
            MonoTime before = MonoTime.currTime;
            parser.setSource(data);
            foreach (e; parser)
            {
            }
            MonoTime after = MonoTime.currTime;
            Duration elapsed = after - before;
            writeln("test ", i,": \t", elapsed, "\t(", data.length, " characters)");
        }
    }
    
    writeln("\n=== CURSOR PERFORMANCE ===");
    void inspectOneLevel(T)(T cursor)
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
    {
        writeln("SliceLexer:");
        auto cursor = XMLCursor!(Parser!(SliceLexer!string))();
        for (int i = 0; i < tests; i++)
        {
            auto data = readText("benchmark/test_" ~ to!string(i) ~ ".xml");
            MonoTime before = MonoTime.currTime;
            cursor.setSource(data);
            inspectOneLevel(cursor);
            MonoTime after = MonoTime.currTime;
            Duration elapsed = after - before;
            writeln("test ", i,": \t", elapsed, "\t(", data.length, " characters)");
        }
    }
    {
        writeln("RangeLexer:");
        auto cursor = XMLCursor!(Parser!(RangeLexer!string))();
        for (int i = 0; i < tests; i++)
        {
            auto data = readText("benchmark/test_" ~ to!string(i) ~ ".xml");
            MonoTime before = MonoTime.currTime;
            cursor.setSource(data);
            inspectOneLevel(cursor);
            MonoTime after = MonoTime.currTime;
            Duration elapsed = after - before;
            writeln("test ", i,": \t", elapsed, "\t(", data.length, " characters)");
        }
    }
}