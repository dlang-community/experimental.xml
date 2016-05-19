
module std.experimental.polymorph;

/++ Marks a struct as base of a hierarchy +/
mixin template BaseClass()
{
    enum size_t[2] _polymorph_template_range = [1, size_t.max];
    enum size_t _polymorph_template_id = 0;
}

/++ Marks a struct as being derived from another; uses alias this internally +/
mixin template DerivedOf(T)
{
    public T _derivedof_template_parent;
    alias _derivedof_template_parent this;
    
    enum size_t[2] _polymorph_template_range = T._hasderived_template_getrange!(typeof(this));
    enum size_t _polymorph_template_id = _polymorph_template_range[0] - 1;
}

/++ Used to enumerate the structs derived from the current; it is mandatory +/
mixin template HasDerived(Ts...)
{
    import std.meta: staticIndexOf;
    
    enum size_t _hasderived_template_partition_length =
        (_polymorph_template_range[1] - _polymorph_template_range[0] ) / Ts.length;
        
    template _hasderived_template_getrange(T)
    {
        enum size_t[2] _hasderived_template_getrange = [
            _polymorph_template_range[0] + staticIndexOf!(T, Ts) * _hasderived_template_partition_length + 1,
            _polymorph_template_range[0] + (staticIndexOf!(T, Ts) + 1) * _hasderived_template_partition_length
        ];
    }
}

/++ Checks whether a struct is derived from another +/
template isDerivedOf(S, T)
{
    static if (__traits(isSame, S, T))
        enum bool isDerivedOf = true;
    else static if (__traits(hasMember, S, "_derivedof_template_parent"))
        enum bool isDerivedOf = isDerivedOf!(typeof(S._derivedof_template_parent), T);
    else
        enum bool isDerivedOf = false;
}

struct PolymorphicRefCounted(NominalType, Types...)
{
    import core.stdc.stdlib: malloc, free;
    import core.stdc.string: memcpy;
    import std.meta: Filter, staticSort, ApplyRight;
    import std.traits: TemplateArgsOf;
    
    private template TagRangeOrder(S, T)
    {
        enum bool TagRangeOrder = S._polymorph_template_range[1] - S._polymorph_template_range[0]
                                <= T._polymorph_template_range[1] - T._polymorph_template_range[0];
    }

    private void* value;
    private ref size_t typeIndexOfThis() const
    {
        return (cast(size_t*)value)[0];
    }
    
    public this(T)(const auto ref T val)
        if (isDerivedOf!(T, NominalType))
    {
        value = malloc(16 + T.sizeof);
        (cast(size_t*)value)[1] = 1;
        typeIndexOfThis = T._polymorph_template_id;
        memcpy(&((cast(size_t*)value)[2]), &val, T.sizeof);
    }
    private this(void* val)
    {
        if(!isNull)
            refCountDec;
        value = val;
        if (!isNull)
            refCountInc;
    }
    public this(this)
    {
        if (!isNull)
            refCountInc;
    }
    public void opAssign(PolymorphicRefCounted other)
    {
        if (!isNull)
            refCountDec;
        value = other.value;
        if (!isNull)
            refCountInc;
    }
    public void opAssign(TRC)(auto ref TRC other)
        if (is(TemplateArgsOf!(TRC)[1..$] == Types))
    {
        alias T = TemplateArgsOf!(TRC)[0];
        static if (isDerivedOf!(T, NominalType))
        {
            if(!isNull)
                refCountDec;
            value = other.value;
            if (!isNull)
                refCountInc;
        }
        else static assert(0, "invalid assignment");
    }
    public ~this()
    {
        if (!isNull)
            refCountDec;
    }
    
    private void refCountInc()
    {
        (cast(size_t*)value)[1]++;
    }
    private void refCountDec()
    {
        auto c = --((cast(size_t*)value)[1]);
        if (!c)
        {
            free(value);
            value = null;
        }
    }
    private size_t refCounter() const
    {
        return (cast(size_t*)value)[1];
    }
    
    auto isNull() const
    {
        return value is null;
    }
    auto opCast(T: bool)() const
    {
        return !isNull;
    }
    
    auto opCast(TRC)()
        if (is(TemplateArgsOf!(TRC)[1..$] == Types))
    {
        alias T = TemplateArgsOf!(TRC)[0];
        static if (isDerivedOf!(NominalType, T))
            return PolymorphicRefCounted!(T, Types)(value);
        else static if (isDerivedOf!(T, NominalType))
        {
            auto id = typeIndexOfThis;
            if (T._polymorph_template_id || (T._polymorph_template_range[0] <= id && id <= T._polymorph_template_range[1]))
                return PolymorphicRefCounted!(T, Types)(value);
            assert(0, "Invalid downcast");
        }
        else
            static assert(0, "Invalid cast");
    }
    
    /++ 
    +   Unwraps the contained object; useful to access private methods, which can't
    +   be accessed using opDispatch.
    +/
    NominalType unwrap()
    {
        if (isNull)
            assert(0, "Unwrapping null PolymorphicRefCounted");
        return *cast(NominalType*)((cast(size_t*)value) + 2);
    }
    
    @property auto ref opDispatch(string s, T)(T t) const
    {
        auto nptr = cast(const(NominalType*))(cast(size_t*)value + 2);
        static if (__traits(compiles, mixin("nptr." ~ s ~ " = t")))
        {
            auto id = typeIndexOfThis;
            foreach (Type; staticSort!(TagRangeOrder, Filter!(ApplyRight!(isDerivedOf, NominalType), Types)))
            {
                auto ptr = cast(const(Type*))(cast(size_t*)value + 2);
                static if (__traits(compiles, mixin("ptr." ~ s ~ " = t")))
                    if (id == Type._polymorph_template_id || (Type._polymorph_template_range[0] <= id && id <= Type._polymorph_template_range[1]))
                    {
                            mixin("return ptr." ~ s ~ " = t;");
                    }
            }
            assert(0);
        }
        else pragma(msg, "WARNING: could not access @property ", typeof(this).stringof, ".", s, " = ", T.stringof);
    }
    
    @property auto ref opDispatch(string s, T)(T t)
    {
        auto nptr = cast(NominalType*)(cast(size_t*)value + 2);
        static if (__traits(compiles, mixin("nptr." ~ s ~ " = t")))
        {
            auto id = typeIndexOfThis;
            foreach (Type; staticSort!(TagRangeOrder, Filter!(ApplyRight!(isDerivedOf, NominalType), Types)))
            {
                auto ptr = cast(Type*)(cast(size_t*)value + 2);
                static if (__traits(compiles, mixin("ptr." ~ s ~ " = t")))
                    if (id == Type._polymorph_template_id || (Type._polymorph_template_range[0] <= id && id <= Type._polymorph_template_range[1]))
                    {
                        mixin("return ptr." ~ s ~ " = t;");
                    }
            }
            assert(0);
        }
        else pragma(msg, "WARNING: could not access @property ", typeof(this).stringof, ".", s, " = ", T.stringof);
    }
    
    auto ref opDispatch(string s, Args...)(Args args) const
    {
        auto nptr = cast(const(NominalType*))(cast(size_t*)value + 2);
        static if ((Args.length == 0 && __traits(compiles, mixin("nptr." ~ s))) || __traits(compiles, mixin("nptr." ~ s ~ "(args)")))
        {
            auto id = typeIndexOfThis;
            foreach (Type; staticSort!(TagRangeOrder, Filter!(ApplyRight!(isDerivedOf, NominalType), Types)))
            {
                auto ptr = cast(const(Type*))(cast(size_t*)value + 2);
                static if ((Args.length == 0 && __traits(compiles, mixin("ptr." ~ s))) || __traits(compiles, mixin("ptr." ~ s ~ "(args)")))
                    if (id == Type._polymorph_template_id || (Type._polymorph_template_range[0] <= id && id <= Type._polymorph_template_range[1]))
                    {
                        static if (Args.length == 0 && __traits(compiles, mixin("ptr." ~ s)))
                            mixin("return ptr." ~ s ~ ";");
                        else static if (__traits(compiles, mixin("ptr." ~ s ~ "(args)")))
                            mixin("return ptr." ~ s ~ "(args);");
                    }
            }
            assert(0);
        }
        else pragma(msg, "WARNING: could not access ", typeof(this).stringof, ".", s, Args.stringof);
    }
    
    auto ref opDispatch(string s, Args...)(Args args)
    {
        auto nptr = cast(NominalType*)(cast(size_t*)value + 2);
        static if ((Args.length == 0 && __traits(compiles, mixin("nptr." ~ s))) || __traits(compiles, mixin("nptr." ~ s ~ "(args)")))
        {
            auto id = typeIndexOfThis;
            foreach (Type; staticSort!(TagRangeOrder, Filter!(ApplyRight!(isDerivedOf, NominalType), Types)))
            {
                auto ptr = cast(Type*)(cast(size_t*)value + 2);
                static if ((Args.length == 0 && __traits(compiles, mixin("ptr." ~ s))) || __traits(compiles, mixin("ptr." ~ s ~ "(args)")))
                    if (id == Type._polymorph_template_id || (Type._polymorph_template_range[0] <= id && id <= Type._polymorph_template_range[1]))
                    {
                        static if (Args.length == 0 && __traits(compiles, mixin("ptr." ~ s)))
                            mixin("return ptr." ~ s ~ ";");
                        else static if (__traits(compiles, mixin("ptr." ~ s ~ "(args)")))
                            mixin("return ptr." ~ s ~ "(args);");
                    }
            }
            assert(0);
        }
        else pragma(msg, "WARNING: could not access ", typeof(this).stringof, ".", s, Args.stringof);
    }
    
    /++
    +   Returns a wrapper for the given object, which must be already wrapped.
    +/
    static PolymorphicRefCounted getWrapperOf(T)(auto ref T val)
    {
        return PolymorphicRefCounted(cast(void*)((cast(size_t*)&val) - 2));
    }
    
    /++
    +   The null value of this type.
    +/
    static enum auto Null = PolymorphicRefCounted(null);
}

/++ UDA used to provide wrapper names for structs +/
struct PolymorphicWrapper
{
    string name;
}

mixin template MakePolymorphicRefCountedHierarchy(Args...)
{
    import std.meta: Filter;
    import std.traits: getUDAs;
    
    private template isType(T)
    {
        enum bool isType = true;
    }
    private template isType(alias T)
    {
        enum bool isType = false;
    }
    private mixin template MakePolymorphicRefCountedHierarchyImpl(size_t pos, Args...)
    {
        static if (pos < Args.length - 1 && is(typeof(Args[pos]) == string))
        {
            mixin("alias " ~ Args[pos] ~ " = PolymorphicRefCounted!(Args[pos + 1], Filter!(isType, Args));");
            mixin MakePolymorphicRefCountedHierarchyImpl!(pos + 2, Args);
        }
        else static if (pos < Args.length && getUDAs!(Args[pos], PolymorphicWrapper).length > 0)
        {
            mixin("alias " ~ getUDAs!(Args[pos], PolymorphicWrapper)[$-1].name ~ " = PolymorphicRefCounted!(Args[pos], Filter!(isType, Args));");
            mixin MakePolymorphicRefCountedHierarchyImpl!(pos + 1, Args);
        }
        else static if (pos < Args.length)
            static assert(0, "Something wrong with the args...");
    }
    mixin MakePolymorphicRefCountedHierarchyImpl!(0, Args);
}

mixin template MakePolymorphicRefCountedHierarchy(alias place)
{
    import std.traits: getSymbolsByUDA, getUDAs;
    
    private mixin template MakePolymorphicRefCountedHierarchyImpl(size_t pos, Types...)
    {
        static if (pos < Types.length)
        {
            mixin("alias " ~ getUDAs!(Types[pos], PolymorphicWrapper)[$-1].name ~ " = PolymorphicRefCounted!(Types[pos], Types);");
            mixin MakePolymorphicRefCountedHierarchyImpl!(pos + 1, Types);
        }
    }
    
    mixin MakePolymorphicRefCountedHierarchyImpl!(0, getSymbolsByUDA!(place, PolymorphicWrapper));
}

void assertAbstract(string f = __PRETTY_FUNCTION__)()
{
    assert(0, "Calling abstract function " ~ f);
}

T assertAbstract(T, string f = __PRETTY_FUNCTION__)()
{
    assert(0, "Calling abstract function " ~ f);
}