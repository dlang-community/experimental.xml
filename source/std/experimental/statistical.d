
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
        int i = 0;
        _variance = cast(parent.InternalType)0;
        foreach(t; data)
        {
            auto val = Reader(t);
            i++;
            
            if (count%2 && i == count/2 + 1)
                _median = val;
            else if (count%2 == 1 && i == count/2)
                _median = val;
            else if (count%2 == 1 && i == count/2 + 1)
                _median = (_median + val)/2;
                
            _variance += (val - _mean)^^2;
        }
        _variance /= count;
    }
}

alias FastStatisticData(T) = FastStatisticData!((T x) => x, (T x) => x);
struct FastStatisticData(alias Printer, alias Reader)
{
    import std.range.primitives: ElementType, isInputRange;
    
    private StatisticData!(Printer, Reader) parent;
    alias parent this;
    
    this(U)(U data)
        if (is(ElementType!U : T) && isInputRange!U)
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
    }
}