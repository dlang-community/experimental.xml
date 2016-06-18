/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module std.experimental.statistical;

struct StatisticData(alias Printer, alias Reader)
{
    import std.traits: Parameters, ReturnType;

    alias InputType = Parameters!Reader[0];
    alias InternalType = ReturnType!Reader;
    alias OutputType = ReturnType!Printer;
    
    private
    {
        InternalType _total;
        InternalType _min;
        InternalType _max;
        InternalType _median;
        InternalType _variance;
    }
    uint count;
    
    @property auto total()
    {
        return Printer(_total);
    }
    @property auto min()
    {
        return Printer(_min);
    }
    @property auto max()
    {
        return Printer(_max);
    }
    @property auto median()
    {
        return Printer(_median);
    }
    @property auto variance()
    {
        return Printer(_variance);
    }
    @property auto mean()
    {
        return Printer(_total/count);
    }
    @property auto deviation()
    {
        import std.conv: to;
        import std.math: sqrt;
        return Printer(_variance.to!real.sqrt.to!InternalType);
    }
}

alias PreciseStatisticData(T) = PreciseStatisticData!((T x) => x, (T x) => x);
struct PreciseStatisticData(alias Printer, alias Reader)
{
    import std.range.primitives: ElementType, isForwardRange;
    
    StatisticData!(Printer, Reader) parent;
    alias parent this;
    
    this(U)(U data)
        if (is(ElementType!U : parent.InputType) && isForwardRange!U)
    {
        foreach(t; data)
        {
            auto val = Reader(t);
            count++;
            if (count == 1)
            {
                _total = val;
                _min = val;
                _max = val;
            }
            else
            {
                _total += val;
                if (val < _min)
                    _min = val;
                if (val > _max)
                    _max = val;
            }
        }
        
        auto _mean = _total/count;
        _variance = cast(parent.InternalType)0;
        foreach(t; data)
            _variance += (Reader(t) - _mean)^^2;
        _variance /= count;
        
        import std.algorithm: topNCopy, SortOutput, map;
        auto firstHalf = new parent.InternalType[count/2 + 1];
        topNCopy(data.map!((x) => Reader(x)), firstHalf, SortOutput.yes);
        if (count % 2)
            _median = firstHalf[$-1];
            
        else
            _median = (firstHalf[$-2] + firstHalf[$-1]) / 2;
    }
}

alias FastStatisticData(T) = FastStatisticData!((T x) => x, (T x) => x);
struct FastStatisticData(alias Printer, alias Reader)
{
    import std.range.primitives: ElementType, isInputRange;
    
    private StatisticData!(Printer, Reader) parent;
    alias parent this;
    
    this(U)(U data)
        if (is(ElementType!U : parent.InputType) && isInputRange!U)
    {
        auto _mean = cast(parent.InternalType)0;
        _variance = _mean;
        _median = _mean;
        foreach(t; data)
        {
            auto val = Reader(t);
            count++;
            if (count == 1)
            {
                _total = val;
                _min = val;
                _max = val;
            }
            else
            {
                _total += val;
                if (val < _min)
                    _min = val;
                if (val > _max)
                    _max = val;
            }
            auto delta = val - _mean;
            _mean += delta / count;
            _variance += delta * (x - mean);
        }
        variance /= count - 1;
        // TODO: implement single pass median calculation using the P^^2 algorithm
    }
}