
module csvplot;

import std.algorithm: canFind, filter, sort, startsWith, splitter, map;
import std.array: appender, array;
import std.conv;
import std.format;
import std.getopt;
import std.stdio;
import std.typecons: Nullable, Tuple;

enum Key
{
    unspecified,
    timestamp,
    configuration,
    component,
    file,
}

enum Value
{
    min,
    max,
    average,
    median,
    deviation,
    sigma,
}

alias Entry = Tuple!(string, "timestamp",
                     string, "component",
                     string, "configuration",
                     string, "file",
                     double, "min",
                     double, "average",
                     double, "max",
                     double, "median",
                     double, "deviation");

string getString(Entry entry, string name)
{
    switch (name)
    {
        case "timestamp": return entry.timestamp;
        case "component": return entry.component;
        case "configuration": return entry.configuration;
        case "file": return entry.file;
        case "unspecified": return "";
        default: assert(0);
    }
}
double getDouble(Entry entry, string name)
{
    switch (name)
    {
        case "min": return entry.min;
        case "average": return entry.average;
        case "max": return entry.max;
        case "median": return entry.median;
        case "deviation": return entry.deviation;
        default: assert(0);
    }
}
                     
void main(string[] args)
{   
    switch (args[1])
    {
        case "plot":
            plot(args);
            break;
            
        case "show":
            break;
            
        default:
            stderr.writeln("Unrecognized command ", args[1]);
    }
}

void plot(ref string[] args)
{
    Key compare;
    Key join;
    Value[] show;
    string[Key] where;
    
    // GET THE PARAMETERS
    arraySep = ",";
    getopt(args, config.caseSensitive, config.bundling,
        config.required, "compare", &compare,
        config.required, "show", &show,
        "join", &join,
        "where", &where,
        );
    
    // CHECK CONSISTENCY OF OPTIONS
    string kind = "P";
    {
        auto keys = where.keys ~ join ~ compare;
        assert(keys.containsAll([Key.timestamp, Key.component]), "Invalid combination of options");
        if (keys.canFind(Key.configuration))
            kind = "C";
        if (keys.canFind(Key.file))
        {
            assert(keys.canFind(Key.configuration), "Invalid combination of options");
            kind = "F";
        }
    }
    
    // FILTER INPUT DATA
    auto data = filter(args[2], where, kind);
    
    // EXTRACT NEEDED COLUMNS
    string[] sortedJoinKeys = [];
    string[] sortedCompareKeys = [];
    double[][string][string] output;
    foreach (entry; data)
    {
        auto joinKey = entry.getString(to!string(join));
        auto compareKey = entry.getString(to!string(compare));
        
        if (!sortedJoinKeys.canFind(joinKey))
            sortedJoinKeys ~= joinKey;
        if (!sortedCompareKeys.canFind(compareKey))
            sortedCompareKeys ~= compareKey;
            
        double[] line = [];
        if (show.canFind(Value.min))
            line ~= entry.min;
        if (show.canFind(Value.average))
            line ~= entry.average;
        if (show.canFind(Value.max))
            line ~= entry.max;
        if (show.canFind(Value.median))
            line ~= entry.median;
        if (show.canFind(Value.deviation))
        {
            line ~= entry.average - entry.deviation;
            line ~= entry.average + entry.deviation;
        }
        if (show.canFind(Value.sigma))
            line ~= entry.deviation;
        output[joinKey][compareKey] = line;
    }
    
    // CALCULATE COLUMN INDEXES
    int[string] column;
    {
        int i = 1;
        if (show.canFind(Value.min))
            column["min"] = i++;
        if (show.canFind(Value.average))
            column["average"] = i++;
        if (show.canFind(Value.max))
            column["max"] = i++;
        if (show.canFind(Value.median))
            column["median"] = i++;
        if (show.canFind(Value.deviation))
        {
            column["deviation_low"] = i++;
            column["deviation_high"] = i++;
        }
        if (show.canFind(Value.sigma))
            column["sigma"] = i++;
    }
    
    // OUTPUT THE DATA
    writeln("$data << EOD");
    foreach (joinKey; sortedJoinKeys)
    {
        foreach (compareKey; sortedCompareKeys)
        {
            if (compareKey in output[joinKey])
                foreach (value; output[joinKey][compareKey])
                    write("\t", value);
            else
                write("?");
                
            writeln();
        }
        writeln();
        writeln();
    }
    writeln("EOD");
    
    // SOME USEFUL VARIABLES
    auto joinCount = sortedJoinKeys.length;
    double boxWidth = (joinCount <= 6)? 0.15 : 0.1;
    string xpos = "($0 - " ~ to!string((joinCount-1)*boxWidth/2) ~ " + column(-2)*" ~ to!string(boxWidth) ~ ")";
    
    // OUTPUT THE CORRECT SCRIPT BASED ON THE PARAMETERS
    writeln();
    writeln("set datafile missing \"?\"");
    writeln("set term svg noenhanced");
    writeln("set xtic rotate by -60");
    writeln("set ylabel 'Speed [MB/s]'");
    writeln("set offsets graph 0.1, graph 0.1, graph 0.1, graph 0.1");
    write("set xtic (");
    foreach (i, compareKey; sortedCompareKeys) write((i > 0)?", \"":"\"", compareKey, "\" ", i);
    writeln(")");
    writeln("set key outside");
    writeln("set boxwidth %f".format(8*boxWidth/10));
    
    writeln("plot \\");
    auto remainShow = show.dup;
    if (remainShow.length == 1 && remainShow[0] != Value.deviation)
    {
        "$data u %s:%d:(column(-2)) notitle w boxes lc variable, \\".format(xpos, column[to!string(remainShow[0])]).writeln;
        remainShow = [];
    }
    if (remainShow.containsAll([Value.min, Value.max, Value.deviation]))
    {
        "$data u %s:%d:%d:%d:%d:(column(-2)) notitle with candlesticks lc variable, \\".format(xpos, column["deviation_low"], column["min"], column["max"], column["deviation_high"]).writeln;
        "$data u (NaN):(NaN):(NaN):(NaN):(NaN):(column(-2)) title \"deviation\" w candlesticks lc \"black\", \\".writeln;
        remainShow = remainShow.filter!(a => !([Value.min, Value.max, Value.deviation].canFind(a))).array;
        if (remainShow.canFind(Value.average))
        {
            "$data u %s:%d:%d:%d:%d:(column(-2)) notitle w candlesticks lc variable, \\".format(xpos, column["average"], column["average"], column["average"], column["average"]).writeln;
            remainShow = remainShow.filter!(a => a != Value.average).array;
        }
    }
    if (remainShow.containsAll([Value.min, Value.max, Value.average]))
    {
        "$data u %s:%d:%d:%d:(column(-2)) notitle w errorbars lc variable, \\".format(xpos, column["average"], column["min"], column["max"]).writeln;
        "$data u (NaN):(NaN):(NaN):(NaN):(column(-2)) title \"min-avg-max\" w errorbars lc variable lt 1, \\".writeln;
        remainShow = remainShow.filter!(a => !([Value.min, Value.max, Value.average].canFind(a))).array;
    }
    if (remainShow.containsAll([Value.min, Value.max, Value.median]))
    {
        "$data u %s:%d:%d:%d:(column(-2)) notitle w errorbars lc variable, \\".format(xpos, column["median"], column["min"], column["max"]).writeln;
        "$data u (NaN):(NaN):(NaN):(NaN):(column(-2)) title \"min-median-max\" w errorbars lc variable lt 1, \\".writeln;
        remainShow = remainShow.filter!(a => !([Value.min, Value.max, Value.median].canFind(a))).array;
    }
    if (remainShow.containsAll([Value.deviation, Value.average]))
    {
        "$data u %s:%d:%d:%d:(column(-2)) notitle w errorbars lc variable, \\".format(xpos, column["average"], column["deviation_low"], column["deviation_high"]).writeln;
        "$data u (NaN):(NaN):(NaN):(NaN):(column(-2)) title \"average and deviation\" w errorbars lc variable lt 1, \\".writeln;
        remainShow = remainShow.filter!(a => !([Value.average, Value.deviation].canFind(a))).array;
    }
    if (remainShow.containsAll([Value.deviation, Value.median]))
    {
        "$data u %s:%d:%d:%d:(column(-2)) notitle w errorbars lc variable, \\".format(xpos, column["average"], column["deviation_low"], column["deviation_high"]).writeln;
        "$data u (NaN):(NaN):(NaN):(NaN):(column(-2)) title \"median and deviation\" w errorbars lc variable lt 1, \\".writeln;
        remainShow = remainShow.filter!(a => !([Value.median, Value.deviation].canFind(a))).array;
    }
    if (remainShow.containsAll([Value.min, Value.max]))
    {
        "$data u %s:(($%d + $%d)/2):%d:%d:(column(-2)) notitle w errorbars lc variable pt -1, \\".format(xpos, column["min"], column["max"], column["min"], column["max"]).writeln;
        "$data u (NaN):(NaN):(NaN):(NaN):(column(-2)) title \"min-max\" w errorbars lc variable pt -1 lt 1, \\".writeln;
        remainShow = remainShow.filter!(a => !([Value.min, Value.max].canFind(a))).array;
    }
    if (remainShow.canFind(Value.median))
    {
        "$data u %s:%d:(column(-2)) notitle lc variable pt 2 ps 0.75, \\".format(xpos, column["median"]).writeln;
        "$data u (NaN):(NaN):(column(-2)) title \"median\" lc \"black\" pt 2, \\".writeln;
        remainShow = remainShow.filter!(a => a != Value.median).array;
    }
    if (remainShow.canFind(Value.average))
    {
        "$data u %s:%d:(column(-2)) notitle lc variable pt 7 ps 0.75, \\".format(xpos, column["average"]).writeln;
        "$data u (NaN):(NaN):(column(-2)) title \"average\" lc \"black\" pt 7, \\".writeln;
        remainShow = remainShow.filter!(a => a != Value.average).array;
    }
    if (remainShow.canFind(Value.sigma))
    {
        "$data u %s:%d:(column(-2)) notitle lc variable pt 4 ps 0.75, \\".format(xpos, column["sigma"]).writeln;
        "$data u (NaN):(NaN):(column(-2)) title \"sigma\" lc \"black\" pt 4, \\".writeln;
        remainShow = remainShow.filter!(a => a != Value.sigma).array;
    }
    if (remainShow.canFind(Value.min))
    {
        "$data u %s:%d:(column(-2)) notitle lc variable pt 10 ps 0.75, \\".format(xpos, column["min"]).writeln;
        "$data u (NaN):(NaN):(column(-2)) title \"min\" lc \"black\" pt 10, \\".writeln;
        remainShow = remainShow.filter!(a => a != Value.min).array;
    }
    if (remainShow.canFind(Value.max))
    {
        "$data u %s:%d:(column(-2)) notitle lc variable pt 8 ps 0.75, \\".format(xpos, column["max"]).writeln;
        "$data u (NaN):(NaN):(column(-2)) title \"max\" lc \"black\" pt 8, \\".writeln;
        remainShow = remainShow.filter!(a => a != Value.max).array;
    }
    "\"+\" u 1:(NaN) title \" \" w dots lc \"white\", \\".writeln;
    foreach (i; 0..joinCount)
        "$data u (NaN):(NaN):(%d) title \"%s\" w boxes lc variable fs solid, \\".format(i, sortedJoinKeys[i]).writeln;
    writeln("dummy = 0");
}

Entry[] filter(string filename, string[Key] where, string kind)
{
    auto result = appender!(Entry[])();
    auto file = File(filename, "r");
    foreach(line; file.byLineCopy)
    {
        if (!line.startsWith(kind))
            continue;
        
        auto values = line.splitter(',').map!"a.strip";
        values.popFront;
        
        Entry entry;
        
        entry.timestamp = values.front; values.popFront;
        entry.component = values.front; values.popFront;
        if (Key.timestamp in where && !entry.timestamp.matches(where[Key.timestamp]))
            continue;
        if (Key.component in where && !entry.component.matches(where[Key.component]))
            continue;
            
        if (kind != "P")
        {
            entry.configuration = values.front; values.popFront;
            if (Key.configuration in where && !entry.configuration.matches(where[Key.configuration]))
                continue;
        }
        if (kind == "F")
        {
            entry.file = values.front; values.popFront;
            if (Key.file in where && !entry.file.matches(where[Key.file]))
                continue;
        }
        entry.min = to!double(values.front); values.popFront;
        entry.average = to!double(values.front); values.popFront;
        entry.max = to!double(values.front); values.popFront;
        entry.median = to!double(values.front); values.popFront;
        entry.deviation = to!double(values.front); values.popFront;
        
        result.put(entry);
    }
    return result.data;
}

bool containsAll(T)(T[] haystack, T[] needles)
{
    foreach(needle; needles)
        if(!haystack.canFind(needle))
            return false;
    return true;
}

bool matches(string target, string re)
{
    if (target == re)
        return true;
    
    import std.regex;
    return matchFirst(target, "^" ~ re ~ "$").hit == target;
}