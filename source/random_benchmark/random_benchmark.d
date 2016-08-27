/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module random_benchmark;

import genxml;
import std.experimental.statistical;

import std.experimental.xml;

import std.array;
import std.stdio;
import std.file;
import std.path: buildPath, exists;
import std.conv;
import core.time: Duration, nsecs;

// BENCHMARK CONFIGURATIONS: TWEAK AS NEEDED

enum BenchmarkConfig theBenchmark = {
    components: [
        ComponentConfig("Memory_bound", "to!string", "iterateString"),
        ComponentConfig("Parser_BufferedLexer_1K", "makeDumbBufferedReader!1024", "parserTest!(BufferedLexer, DumbBufferedReader)"),
        ComponentConfig("Parser_BufferedLexer_64K", "makeDumbBufferedReader!65536", "parserTest!(BufferedLexer, DumbBufferedReader)"),
        ComponentConfig("Parser_SliceLexer", "to!string", "parserTest!SliceLexer"),
        ComponentConfig("Parser_ForwardLexer", "to!string", "parserTest!ForwardLexer"),
        ComponentConfig("Parser_RangeLexer", "to!string", "parserTest!RangeLexer"),
        ComponentConfig("Cursor_BufferedLexer_1K", "makeDumbBufferedReader!1024", "cursorTest!(BufferedLexer, DumbBufferedReader)"),
        ComponentConfig("Cursor_BufferedLexer_64K", "makeDumbBufferedReader!65536", "cursorTest!(BufferedLexer, DumbBufferedReader)"),
        ComponentConfig("Cursor_SliceLexer", "to!string", "cursorTest!SliceLexer"),
        ComponentConfig("Cursor_ForwardLexer", "to!string", "cursorTest!ForwardLexer"),
        ComponentConfig("Cursor_RangeLexer", "to!string", "cursorTest!RangeLexer"),
        ComponentConfig("Legacy_SAX_API", "to!string", "oldSAXTest!\"std.xml\""),
        ComponentConfig("Legacy_SAX_Emulator", "to!string","oldSAXTest!\"std.experimental.xml.legacy\""),
        ComponentConfig("Legacy_DOM_API", "to!string", "buildOldDOM"),
        ComponentConfig("DOMBuilder_SliceLexer", "to!string", "buildDOM"),
    ],
    configurations: [
        K100,
        M1,
        M10,
        M100,
    ],
    filesPerConfig: 3,
    runsPerFile: 5,
};

enum GenXmlConfig M100 = { name: "M100",
                           minDepth:         6,
                           maxDepth:        14,
                           minChilds:        3,
                           maxChilds:        9,
                           minAttributeNum:  0,
                           maxAttributeNum:  5};

enum GenXmlConfig M10 = { name: "M10",
                          minDepth:         5,
                          maxDepth:        13,
                          minChilds:        3,
                          maxChilds:        8,
                          minAttributeNum:  0,
                          maxAttributeNum:  4};

enum GenXmlConfig M1 = { name: "M1",
                         minDepth:         5,
                         maxDepth:        12,
                         minChilds:        4,
                         maxChilds:        7,
                         minAttributeNum:  1,
                         maxAttributeNum:  4};
                          
enum GenXmlConfig K100 = { name: "K100",
                           minDepth:         4,
                           maxDepth:        11,
                           minChilds:        3,
                           maxChilds:        6,
                           minAttributeNum:  1,
                           maxAttributeNum:  3};

// FUNCTIONS USED FOR TESTING

struct DumbBufferedReader
{
    string content;
    size_t chunk_size;
    
    void popFront() @nogc
    {
        if (content.length > chunk_size)
            content = content[chunk_size..$];
        else
            content = [];
    }
    string front() const @nogc
    {
        if (content.length >= chunk_size)
            return content[0..chunk_size];
        else
            return content[0..$];
    }
    bool empty() const @nogc
    {
        return !content.length;
    }
}

DumbBufferedReader makeDumbBufferedReader(size_t bufferSize)(string s)
{
    return DumbBufferedReader(s, bufferSize);
}

void parserTest(alias Lexer, T = string)(T data)
{
    auto parser = Parser!(Lexer!(T, void delegate()), void delegate())();
    parser.setSource(data);
    foreach(e; parser)
    {
        doNotOptimize(e);
    }
}

void cursorTest(alias Lexer, T = string)(T data)
{
    auto cursor = Cursor!(Parser!(Lexer!(T, void delegate()), void delegate()))();
    cursor.setSource(data);
    inspectOneLevel(cursor);
}
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

void oldSAXTest(string api)(string data)
{
    mixin("import " ~ api ~ ";\n");
    
    void recursiveParse(ElementParser parser)
    {
        doNotOptimize(cast(Tag)(parser.tag));
        parser.onStartTag[null] = &recursiveParse;
        parser.parse;
    }
    
    DocumentParser parser = new DocumentParser(data);
    recursiveParse(parser);
}

void buildOldDOM(string data)
{
    import std.xml;
    doNotOptimize(new Document(data));
}

void buildDOM(string data)
{
    auto builder =
         chooseParser!data
        .cursor
        .domBuilder;
    builder.setSource(data);
    
    builder.buildRecursive;
    doNotOptimize(builder.getDocument);
}

void iterateString(string data)
{
    foreach (i; 0..data.length)
        doNotOptimize(data[i]);
}

void doNotOptimize(T)(auto ref T result)
{
    import std.process: thisProcessID;
    if (thisProcessID == 1)
        writeln(result);
}

// MAIN TEST DRIVER
void main(string[] args)
{
    void delegate(FileStats[string], ComponentResults[string]) printFunction;
    if (args.length > 1)
    {
        switch(args[1])
        {
            case "csv":
                printFunction = (stats, results) { printResultsCSV(theBenchmark, results); };
                break;
            case "pretty":
                printFunction = (stats, results)
                {
                    printResultsByConfiguration(theBenchmark, stats, results);
                    printResultsSpeedSummary(theBenchmark, results);
                    writeln("\n\n If you are watching this on a terminal, you are encouraged to redirect the standard output to a file instead.\n");
                };
                break;
            default:
                stderr.writeln("Error: output format ", args[1], "is not supported!");
                return;
        }
    }
    else
    {
        printFunction = (stats, results)
        {
            printResultsByConfiguration(theBenchmark, stats, results);
            printResultsSpeedSummary(theBenchmark, results);
            writeln("\n\n If you are watching this on a terminal, you are encouraged to redirect the standard output to a file instead.\n");
        };
    }
    stderr.writeln("Generating test files...");
    auto stats = generateTestFiles(theBenchmark);
    stderr.writeln("\nPerforming tests...");
    auto results = performBenchmark!theBenchmark;
    stderr.writeln();
    printFunction(stats, results);
}

// STRUCTURES HOLDING PARAMETERS AND RESULTS

struct BenchmarkConfig
{
    uint runsPerFile;
    uint filesPerConfig;
    ComponentConfig[] components;
    GenXmlConfig[] configurations;
}

struct ComponentConfig
{
    string name;
    string inputFunction;
    string benchmarkFunction;
}

struct ComponentResults
{
    PreciseStatisticData!double speedStat;
    ConfigResults[string] configResults;
}

struct ConfigResults
{
    PreciseStatisticData!double speedStat;
    FileResults[string] fileResults;
}

struct FileResults
{
    PreciseStatisticData!(((long x) => nsecs(x)), (Duration d) => d.total!"nsecs") timeStat;
    PreciseStatisticData!double speedStat;
    Duration[] times;
    double[] speeds;
}

// CODE FOR TESTING

mixin template BenchmarkFunctions(ComponentConfig[] comps, size_t pos = 0)
{
    mixin("auto " ~ comps[pos].name ~ "_BenchmarkFunction(string data) {"
            "import core.time: MonoTime;"
            "auto input = " ~ comps[pos].inputFunction ~ "(data);"
            "MonoTime before = MonoTime.currTime;"
            ~ comps[pos].benchmarkFunction ~ "(input);"
            "MonoTime after = MonoTime.currTime;"
            "return after - before;"
            "}"
        );
            
    static if (pos + 1 < comps.length)
        mixin BenchmarkFunctions!(comps, pos + 1);
}

auto performBenchmark(BenchmarkConfig benchmark)()
{
    import std.meta;

    enum ComponentConfig[] theComponents = theBenchmark.components;
    mixin BenchmarkFunctions!(theComponents);
    
    total_tests = benchmark.runsPerFile * benchmark.filesPerConfig * benchmark.configurations.length * benchmark.components.length;
    ComponentResults[string] results;
    foreach(component; aliasSeqOf!(theComponents))
        results[component.name] = testComponent(benchmark, mixin("&" ~ component.name ~ "_BenchmarkFunction"));
        
    return results;
}

auto testComponent(BenchmarkConfig benchmark, Duration delegate(string) fun)
{
    import std.algorithm: map, joiner;
    
    ComponentResults results;
    foreach (config; benchmark.configurations)
        results.configResults[config.name] = testConfiguration(config.name, benchmark.filesPerConfig, benchmark.runsPerFile, fun);
    
    results.speedStat = PreciseStatisticData!double(results.configResults.byValue.map!"a.fileResults.byValue".joiner.map!"a.speeds".joiner);
    return results;
}

auto testConfiguration(string config, uint files, uint runs, Duration delegate(string) fun)
{
    import std.algorithm: map, joiner;
    
    ConfigResults results;
    foreach (filename; getConfigFiles(config, files))
        results.fileResults[filename] = testFile(filename, runs, fun);
        
    results.speedStat = PreciseStatisticData!double(results.fileResults.byValue.map!"a.speeds".joiner);
    return results;
}

ulong total_tests;
ulong performed_tests;
auto testFile(string name, uint runs, Duration delegate(string) fun)
{
    import core.memory;
        
    FileResults results;
    auto input = readText(name);
    foreach (run; 0..runs)
    {
        GC.disable;
        auto time = fun(input);
        GC.enable;
        
        results.times ~= time;
        results.speeds ~= (cast(double)getSize(name)) / time.total!"usecs";
        stderr.writef("\r%d out of %d tests performed", ++performed_tests, total_tests);
        
        GC.collect();
    }
    results.timeStat = typeof(results.timeStat)(results.times);
    results.speedStat = PreciseStatisticData!double(results.speeds);
    return results;
}

string[] getConfigFiles(string config, uint maxFiles)
{
    string[] results = [];
    int count = 1;
    while(count <= maxFiles && buildPath("random-benchmark", config ~ "_" ~ to!string(count) ~ ".xml").exists)
    {
        results ~= buildPath("random-benchmark", config ~ "_" ~ to!string(count) ~ ".xml");
        count++;
    }
    return results;
}

auto generateTestFiles(BenchmarkConfig benchmark)
{
    if(!exists("random-benchmark"))
        mkdir("random-benchmark");

    FileStats[string] results;
        
    total_files = benchmark.filesPerConfig * benchmark.configurations.length;
    foreach (config; benchmark.configurations)
        results.merge!"a"(generateTestFiles(config, config.name, benchmark.filesPerConfig));
        
    return results;
}

ulong total_files;
ulong generated_files;
auto generateTestFiles(GenXmlConfig config, string name, int count)
{
    FileStats[string] results;

    foreach (i; 0..count)
    {
        auto filename = buildPath("random-benchmark", name ~ "_" ~ to!string(i+1) ~".xml" );
        if(!filename.exists)
        {
            auto file = File(filename, "w");
            results[filename] = genDocument(file.lockingTextWriter, config);
        }
        else
            results[filename] = FileStats.init;
        stderr.writef("\r%d out of %d files generated", ++generated_files, total_files);
    }
    return results;
}

void merge(alias f, V, K)(ref V[K] first, const V[K] second)
{
    import std.functional: binaryFun;
    alias fun = binaryFun!f;
    
    foreach (kv; second.byKeyValue)
        if (kv.key in first)
            first[kv.key] = fun(first[kv.key], kv.value);
        else
            first[kv.key] = kv.value;
}

// CODE FOR PRETTY PRINTING

string center(string str, ulong totalSpace)
{
    Appender!string result;
    auto whiteSpace = totalSpace - str.length;
    ulong before = whiteSpace / 2;
    foreach (i; 0..before)
        result.put(' ');
    result.put(str);
    foreach (i; before..whiteSpace)
        result.put(' ');
    return result.data;
}

Duration round(string unit)(Duration d)
{
    import core.time: dur;
    return dur!unit(d.total!unit);
}

void printTimesForConfiguration(BenchmarkConfig benchmark, ComponentResults[string] results, string config)
{
    import std.algorithm: max, map, maxCount;
    import std.range: repeat, take;
    auto component_width = max(results.byKey.map!"a.length".maxCount[0], 8);
    auto std_width = 16;
    
    string formatDuration(Duration d)
    {
        import std.format: format;
        auto millis = d.total!"msecs";
        if (millis < 1000)
            return format("%3u ms", millis);
        else if (millis < 10000)
            return format("%.2f s", millis/1000.0);
        else if (millis < 100000)
            return format("%.1f s", millis/1000.0);
        else
            return to!string(millis/1000) ~ " s";
    }
    
    foreach (component; benchmark.components)
    {
        write("\r  " , component.name, ":", repeat(' ').take(component_width - component.name.length));
        foreach (file; config.getConfigFiles(benchmark.filesPerConfig))
        {
            auto res = results[component.name].configResults[config].fileResults[file].timeStat;
            write(center("min: " ~ formatDuration(res.min), std_width));
            write(center("avg: " ~ formatDuration(res.mean), std_width));
            write(center("max: " ~ formatDuration(res.max), std_width));
            write(center("median: " ~ formatDuration(res.median), std_width + 3));
            writeln(center("deviation: " ~ formatDuration(res.deviation), std_width + 6));
            write(repeat(' ').take(component_width+3));
        }
    }
    writeln();
}

void printSpeedsForConfiguration(BenchmarkConfig benchmark, ComponentResults[string] results, string config)
{
    import std.range: repeat, take;
    import std.algorithm: max, map, maxCount;
    import std.format: format;

    auto component_width = max(results.byKey.map!"a.length".maxCount[0], 13);
    auto speed_column_width = 8UL;
    auto large_column_width = 12;
    auto spaces = repeat(' ');
    auto lines = repeat('-');
    auto boldLines = repeat('=');
    write(spaces.take(component_width));
    foreach (i; 0..benchmark.filesPerConfig)
    {
        write("|");
        write(center("file " ~ to!string(i+1), 3*speed_column_width + 2));
    }
    writeln();
    write(spaces.take(component_width));
    foreach (i; 0..benchmark.filesPerConfig)
    {
        write("|");
        write(lines.take(3*speed_column_width + 2));
    }
    writeln();
    write(center("Speeds (MB/s)", component_width));
    foreach (i; 0..benchmark.filesPerConfig)
    {
        write("|");
        write(center("min", speed_column_width));
        write("|");
        write(center("avg", speed_column_width));
        write("|");
        write(center("max", speed_column_width));
    }
    writeln();
    write(spaces.take(component_width));
    foreach (i; 0..benchmark.filesPerConfig)
    {
        write("|");
        write(lines.take(3*speed_column_width + 2));
    }
    writeln();
    write(spaces.take(component_width));
    foreach (i; 0..benchmark.filesPerConfig)
    {
        write("|");
        write(center("median", large_column_width));
        write("|");
        write(center("deviation", large_column_width + 1));
    }
    writeln();
    foreach (component; benchmark.components)
    {
        writeln(boldLines.take(component_width + benchmark.filesPerConfig*(3 + 3*speed_column_width)));
        write(spaces.take(component_width));
        foreach (file; getConfigFiles(config, benchmark.filesPerConfig))
        {
            auto fres = results[component.name].configResults[config].fileResults[file];
            write("|");
            write(center(format("%6.2f", fres.speedStat.min), speed_column_width));
            write("|");
            write(center(format("%6.2f", fres.speedStat.mean), speed_column_width));
            write("|");
            write(center(format("%6.2f", fres.speedStat.max), speed_column_width));
        }
        writeln();
        write(center(component.name, component_width));
        foreach (i; 0..benchmark.filesPerConfig)
        {
            write("|");
            write(lines.take(3*speed_column_width + 2));
        }
        writeln();
        write(spaces.take(component_width));
        foreach (file; getConfigFiles(config, benchmark.filesPerConfig))
        {
            auto fres = results[component.name].configResults[config].fileResults[file];
            write("|");
            write(center(format("%6.2f", fres.speedStat.median), large_column_width));
            write("|");
            write(center(format("%6.2f", fres.speedStat.deviation), large_column_width + 1));
        }
        writeln();
    }
}

void printFilesForConfiguration(string config, uint maxFiles, FileStats[string] filestats)
{
    import std.algorithm: each, map, max, maxCount;
    import std.path: pathSplitter, stripExtension;
    import std.file: getSize;
    
    ulong columnWidth = 16;
    
    void writeSized(ulong value, string measure = " ")
    {
        import std.format: format;
        import std.range: repeat, take;
        import std.math: ceil, log10;
        
        string formatted;
        if (!value)
        {
            formatted = "  0 ";
        }
        else
        {
            static immutable string[] order = [" ", " k", " M", " G", " T"];
            auto lg = cast(int)ceil(log10(value));
            auto dec = (lg%3 == 0)? 0 : 3 - lg%3;
            auto ord = (lg-1)/3;
            auto val = value/(1000.0^^ord);
            auto fmt = (dec?"":" ") ~ "%." ~ to!string(dec) ~ "f";
            auto f = format(fmt, val);
            formatted = f ~ order[ord];
        }
        formatted ~= measure;
        formatted.center(columnWidth).write;
    }
    void writeAttribute(string attr, string measure = " ")()
    {
        foreach(name; config.getConfigFiles(maxFiles))
        {
            if (filestats[name] != FileStats.init)
                mixin("writeSized(filestats[name]." ~ attr ~ ", \"" ~ measure ~ "\");");
            else
                center("-", columnWidth).write;
        }
    }
    
    write("\n  names:             ");
    foreach(name; config.getConfigFiles(maxFiles))
        name.pathSplitter.back.stripExtension.center(columnWidth).write;
        
    write("\n  total file size:   ");
    foreach(name; config.getConfigFiles(maxFiles))
        writeSized(name.getSize(), "B");
        
    write("\n  raw text content:  ");
    writeAttribute!("textChars", "B");
        
    write("\n  useless spacing:   ");
    writeAttribute!("spaces", "B");
            
    write("\n  total nodes:       ");
    foreach(name; config.getConfigFiles(maxFiles))
        if (filestats[name] != FileStats.init)
        {
            auto stat = filestats[name];
            auto total = stat.elements + stat.textNodes + stat.cdataNodes + stat.processingInstructions + stat.comments + stat.attributes;
            writeSized(total);
        }
        else
            center("-", columnWidth).write;
            
    write("\n  element nodes:     ");
    writeAttribute!("elements");
            
    write("\n  attribute nodes:   ");
    writeAttribute!("attributes", "B");
            
    write("\n  text nodes:        ");
    writeAttribute!("textNodes", "B");
            
    write("\n  cdata nodes:       ");
    writeAttribute!("cdataNodes", "B");
            
    write("\n  comment nodes:     ");
    writeAttribute!("comments", "B");
    writeln();
}

void printResultsByConfiguration(BenchmarkConfig benchmark, FileStats[string] filestats, ComponentResults[string] results)
{
    uint i = 1;
    foreach (config; benchmark.configurations)
    {
        writeln("\n=== CONFIGURATION " ~ to!string(i) ~ ": " ~ config.name ~ " ===\n");
        writeln("Timings:\n");
        printTimesForConfiguration(benchmark, results, config.name);
        printSpeedsForConfiguration(benchmark, results, config.name);
        writeln("\nConfiguration Parameters:");
        config.prettyPrint(2).write;
        writeln("\nFile Statistics (only for newly created files):");
        printFilesForConfiguration(config.name, benchmark.filesPerConfig, filestats);
        i++;
    }
}

void printResultsSpeedSummary(BenchmarkConfig benchmark, ComponentResults[string] results)
{
    import std.range: repeat, take;
    import std.algorithm: max, map, maxCount;
    import std.format: format;

    auto component_width = max(results.byKey.map!"a.length".maxCount[0], 13);
    auto speed_column_width = 8UL;
    auto large_column_width = 12;
    auto spaces = repeat(' ');
    auto lines = repeat('-');
    auto boldLines = repeat('=');
    
    writeln("\n=== CONFIGURATIONS SUMMARY ===\n");
    
    write(spaces.take(component_width));
    foreach (i; 0..benchmark.configurations.length)
    {
        write("|");
        write(center("config " ~ to!string(i+1), 3*speed_column_width + 2));
    }
    writeln();
    write(spaces.take(component_width));
    foreach (i; 0..benchmark.configurations.length)
    {
        write("|");
        write(lines.take(3*speed_column_width + 2));
    }
    writeln();
    write(center("Speeds (MB/s)", component_width));
    foreach (i; 0..benchmark.configurations.length)
    {
        write("|");
        write(center("min", speed_column_width));
        write("|");
        write(center("avg", speed_column_width));
        write("|");
        write(center("max", speed_column_width));
    }
    writeln();
    write(spaces.take(component_width));
    foreach (i; 0..benchmark.configurations.length)
    {
        write("|");
        write(lines.take(3*speed_column_width + 2));
    }
    writeln();
    write(spaces.take(component_width));
    foreach (i; 0..benchmark.configurations.length)
    {
        write("|");
        write(center("median", large_column_width));
        write("|");
        write(center("deviation", large_column_width + 1));
    }
    writeln();
    foreach (component; benchmark.components)
    {
        writeln(boldLines.take(component_width + benchmark.configurations.length*(3 + 3*speed_column_width)));
        write(spaces.take(component_width));
        foreach (config; benchmark.configurations)
        {
            auto fres = results[component.name].configResults[config.name];
            write("|");
            write(center(format("%6.2f", fres.speedStat.min), speed_column_width));
            write("|");
            write(center(format("%6.2f", fres.speedStat.mean), speed_column_width));
            write("|");
            write(center(format("%6.2f", fres.speedStat.max), speed_column_width));
        }
        writeln();
        write(center(component.name, component_width));
        foreach (i; 0..benchmark.configurations.length)
        {
            write("|");
            write(lines.take(3*speed_column_width + 2));
        }
        writeln();
        write(spaces.take(component_width));
        foreach (config; benchmark.configurations)
        {
            auto fres = results[component.name].configResults[config.name];
            write("|");
            write(center(format("%6.2f", fres.speedStat.median), large_column_width));
            write("|");
            write(center(format("%6.2f", fres.speedStat.deviation), large_column_width + 1));
        }
        writeln();
    }
}

void printResultsCSV(BenchmarkConfig benchmark, ComponentResults[string] results)
{
    import std.datetime: Clock;
    import core.time: ClockType;
    auto now = Clock.currTime!(ClockType.second);
    auto timeStr = now.toISOExtString;
    
    import std.format: format;
    auto fmtP = "P, " ~ timeStr ~ ", %s, %f, %f, %f, %f, %f";
    auto fmtC = "C, " ~ timeStr ~ ", %s, %s, %f, %f, %f, %f, %f";
    auto fmtF = "F, " ~ timeStr ~ ", %s, %s, %s, %f, %f, %f, %f, %f";
    
    foreach (component; benchmark.components)
    {
        auto compStats = results[component.name].speedStat;
        fmtP.format(component.name, compStats.min, compStats.mean, compStats.max, compStats.median, compStats.deviation).writeln;
        
        foreach (config; benchmark.configurations)
        {
            auto confStats = results[component.name].configResults[config.name].speedStat;
            fmtC.format(component.name, config.name, confStats.min, confStats.mean, confStats.max, confStats.median, confStats.deviation).writeln;
        
            foreach (file, fileResults; results[component.name].configResults[config.name].fileResults)
            {
                auto fileStats = fileResults.speedStat;
                fmtF.format(component.name, config.name, file, fileStats.min, fileStats.mean, fileStats.max, fileStats.median, fileStats.deviation).writeln;
            }
        }
    }
}
