/++
FGHJ Representation

Copyright: Tamedia Digital, 2016

Authors: Ilya Yaroshenko

License: MIT

Macros:
SUBMODULE = $(LINK2 fghj_$1.html, fghj.$1)
SUBREF = $(LINK2 fghj_$1.html#.$2, $(TT $2))$(NBSP)
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
T4=$(TR $(TDNW $(LREF $1)) $(TD $2) $(TD $3) $(TD $4))
+/
module fghj.fghj;

import std.exception;
import std.range.primitives;
import std.typecons;
import std.traits;

import fghj.jsonbuffer;
import fghj.jsonparser: assumePure;

version(X86_64)
    version = X86_Any;
else
version(X86)
    version = X86_Any;

version (D_Exceptions)
{
    import mir.serde: SerdeException;
    /++
    Serde Exception
    +/
    class FghjSerdeException : SerdeException
    {
        /// zero based faulty location
        size_t location;

        ///
        this(
            string msg,
            size_t location,
            string file = __FILE__,
            size_t line = __LINE__,
            ) pure nothrow @nogc @safe 
        {
            this.location = location;
            super(msg, file, line);
        }

        ///
        this(
            string msg,
            string file = __FILE__,
            size_t line = __LINE__,
            Throwable next = null) pure nothrow @nogc @safe 
        {
            super(msg, file, line, next);
        }

        ///
        this(
            string msg,
            Throwable next,
            string file = __FILE__,
            size_t line = __LINE__,
            ) pure nothrow @nogc @safe 
        {
            this(msg, file, line, next);
        }

        override FghjSerdeException toMutable() @trusted pure nothrow @nogc const
        {
            return cast() this;
        }

        alias toMutable this;
    }
}

deprecated("use mir.serde: SerdeException instead")
alias FghjException = SerdeException;

///
class InvalidFghjException: SerdeException
{
    ///
    this(
        uint kind,
        string file = __FILE__,
        size_t line = __LINE__,
        Throwable next = null) pure nothrow @safe 
    {
        import mir.format: text;
        super(text("FGHJ values is invalid for kind = ", kind), file, line, next);
    }

    ///
    this(
        uint kind,
        Throwable next,
        string file = __FILE__,
        size_t line = __LINE__,
        ) pure nothrow @safe 
    {
        this(kind, file, line, next);
    }
}

private void enforceValidFghj(
        bool condition,
        uint kind,
        string file = __FILE__,
        size_t line = __LINE__) @safe pure
{
    if(!condition)
        throw new InvalidFghjException(kind, file, line);
}

///
class EmptyFghjException: SerdeException
{
    ///
    this(
        string msg = "FGHJ value is empty",
        string file = __FILE__,
        size_t line = __LINE__,
        Throwable next = null) pure nothrow @nogc @safe 
    {
        super(msg, file, line, next);
    }
}

/++
The structure for FGHJ manipulation.
+/
struct Fghj
{
    ///
    enum Kind : ubyte
    {
        ///
        null_  = 0x00,
        ///
        true_  = 0x01,
        ///
        false_ = 0x02,
        ///
        number = 0x03,
        ///
        string = 0x05,
        ///
        array  = 0x09,
        ///
        object = 0x0A,
    }

    /// Returns FGHJ Kind
    ubyte kind() const pure @safe @nogc
    {
        if (!data.length)
        {
            static immutable exc = new EmptyFghjException;
            throw exc;
        }
        return data[0];
    }

    /++
    Plain FGHJ data.
    +/
    ubyte[] data;

    /// Creates FGHJ using already allocated data
    this(ubyte[] data) pure @safe nothrow @nogc
    {
        this.data = data;
    }

    /// Creates FGHJ from a string
    this(in char[] str) pure @safe
    {
        data = new ubyte[str.length + 5];
        data[0] = Kind.string;
        length4 = str.length;
        data[5 .. $] = cast(const(ubyte)[])str;
    }

    ///
    unittest
    {
        assert(Fghj("string") == "string");
        assert(Fghj("string") != "String");
    }

    // \uXXXX character support
    unittest
    {
        import mir.conv: to;
        import fghj.jsonparser;
        assert(Fghj("begin\u000bend").to!string == `"begin\u000Bend"`);
        assert("begin\u000bend" == cast(string) `"begin\u000Bend"`.parseJson, to!string(cast(ubyte[]) cast(string)( `"begin\u000Bend"`.parseJson)));
    }

    /// Sets deleted bit on
    void remove() pure @safe nothrow @nogc
    {
        if(data.length)
            data[0] |= 0x80;
    }

    ///
    unittest
    {
        import mir.conv: to;
        import fghj.jsonparser;
        auto fghjData = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`.parseJson;
        fghjData["inner", "d"].remove;
        assert(fghjData.to!string == `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","e":{}}}`);
    }

    ///
    void toString(Dg)(scope Dg sink) const
    {
        scope buffer = JsonBuffer!Dg(sink);
        toStringImpl(buffer);
        buffer.flush;
    }

    /+
    Internal recursive toString implementation.
    Params:
        sink = output range that accepts `char`, `in char[]` and compile time string `(string str)()`
    +/
    private void toStringImpl(Dg)(ref JsonBuffer!Dg sink) const
    {
        if (!data.length)
        {
            static immutable exc = new EmptyFghjException("Data buffer is empty");
            throw exc;
        }
        auto t = data[0];
        switch(t)
        {
            case Kind.null_:
                enforceValidFghj(data.length == 1, t);
                sink.put!"null";
                break;
            case Kind.true_:
                enforceValidFghj(data.length == 1, t);
                sink.put!"true";
                break;
            case Kind.false_:
                enforceValidFghj(data.length == 1, t);
                sink.put!"false";
                break;
            case Kind.number:
                enforceValidFghj(data.length > 1, t);
                size_t length = data[1];
                enforceValidFghj(data.length == length + 2, t);
                sink.putSmallEscaped(cast(const(char)[]) data[2 .. $]);
                break;
            case Kind.string:
                enforceValidFghj(data.length >= 5, Kind.object);
                enforceValidFghj(data.length == length4 + 5, t);
                sink.put('"');
                sink.put(cast(const(char)[]) data[5 .. $]);
                sink.put('"');
                break;
            case Kind.array:
                auto elems = Fghj(cast(ubyte[])data).byElement;
                if(elems.empty)
                {
                    sink.put!"[]";
                    break;
                }
                sink.put('[');
                elems.front.toStringImpl(sink);
                elems.popFront;
                foreach(e; elems)
                {
                    sink.put(',');
                    e.toStringImpl(sink);
                }
                sink.put(']');
                break;
            case Kind.object:
                auto pairs = Fghj(cast(ubyte[])data).byKeyValue;
                if(pairs.empty)
                {
                    sink.put!"{}";
                    break;
                }
                sink.put!"{\"";
                sink.put(pairs.front.key);
                sink.put!"\":";
                pairs.front.value.toStringImpl(sink);
                pairs.popFront;
                foreach(e; pairs)
                {
                    sink.put!",\"";
                    sink.put(e.key);
                    sink.put!"\":";
                    e.value.toStringImpl(sink);
                }
                sink.put('}');
                break;
            default:
                enforceValidFghj(0, t);
        }
    }

    ///
    unittest
    {
        import mir.conv: to;
        import fghj.jsonparser;
        auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
        const fghjData = text.parseJson;
        assert(fghjData.to!string == text);
    }

    /++
    `==` operator overloads for `null`
    +/
    bool opEquals(in Fghj rhs) const @safe pure nothrow @nogc
    {
        return data == rhs.data;
    }

    ///
    unittest
    {
        import fghj.jsonparser;
        auto fghjData = `null`.parseJson;
        assert(fghjData == fghjData);
    }

    /++
    `==` operator overloads for `null`
    +/
    bool opEquals(typeof(null)) const pure @safe nothrow
    {
        return data.length == 1 && data[0] == 0;
    }

    ///
    unittest
    {
        import fghj.jsonparser;
        auto fghjData = `null`.parseJson;
        assert(fghjData == null);
    }

    /++
    `==` operator overloads for `bool`
    +/
    bool opEquals(bool boolean) const pure @safe nothrow
    {
        return data.length == 1 && (data[0] == Kind.true_ && boolean || data[0] == Kind.false_ && !boolean);
    }

    ///
    unittest
    {
        import fghj.jsonparser;
        auto fghjData = `true`.parseJson;
        assert(fghjData == true);
        assert(fghjData != false);
    }

    /++
    `==` operator overloads for `string`
    +/
    bool opEquals(in char[] str) const pure @trusted nothrow
    {
        return data.length >= 5 && data[0] == Kind.string && data[5 .. 5 + length4] == cast(const(ubyte)[]) str;
    }

    ///
    unittest
    {
        import fghj.jsonparser;
        auto fghjData = `"str"`.parseJson;
        assert(fghjData == "str");
        assert(fghjData != "stR");
    }

    /++
    Returns:
        input range composed of elements of an array.
    +/
    auto byElement() pure
    {
        static struct Range
        {
            private ubyte[] _data;
            private Fghj _front;

            auto save()() pure @property
            {
                return this;
            }

            void popFront() pure
            {
                while(!_data.empty)
                {
                    uint t = cast(ubyte) _data.front;
                    switch(t)
                    {
                        case Kind.null_:
                        case Kind.true_:
                        case Kind.false_:
                            _front = Fghj(_data[0 .. 1]);
                            _data.popFront;
                            return;
                        case Kind.number:
                            enforceValidFghj(_data.length >= 2, t);
                            size_t len = _data[1] + 2;
                            enforceValidFghj(_data.length >= len, t);
                            _front = Fghj(_data[0 .. len]);
                            _data = _data[len .. $];
                            return;
                        case Kind.string:
                        case Kind.array:
                        case Kind.object:
                            enforceValidFghj(_data.length >= 5, t);
                            size_t len = Fghj(_data).length4 + 5;
                            enforceValidFghj(_data.length >= len, t);
                            _front = Fghj(_data[0 .. len]);
                            _data = _data[len .. $];
                            return;
                        case 0x80 | Kind.null_:
                        case 0x80 | Kind.true_:
                        case 0x80 | Kind.false_:
                            _data.popFront;
                            continue;
                        case 0x80 | Kind.number:
                            enforceValidFghj(_data.length >= 2, t);
                            _data.popFrontExactly(_data[1] + 2);
                            continue;
                        case 0x80 | Kind.string:
                        case 0x80 | Kind.array:
                        case 0x80 | Kind.object:
                            enforceValidFghj(_data.length >= 5, t);
                            size_t len = Fghj(_data).length4 + 5;
                            _data.popFrontExactly(len);
                            continue;
                        default:
                            enforceValidFghj(0, t);
                    }
                }
                _front = Fghj.init;
            }

            auto front() pure @property
            {
                assert(!empty);
                return _front;
            }

            bool empty() pure @property
            {
                return _front.data.length == 0;
            }
        }
        if(data.empty || data[0] != Kind.array)
            return Range.init;
        enforceValidFghj(data.length >= 5, Kind.array);
        enforceValidFghj(length4 == data.length - 5, Kind.array);
        auto ret = Range(data[5 .. $]);
        if(ret._data.length)
            ret.popFront;
        return ret;
    }

    /++
    Returns:
        Input range composed of key-value pairs of an object.
        Elements are type of `Tuple!(const(char)[], "key", Fghj, "value")`.
    +/
    auto byKeyValue() pure
    {
        static struct Range
        {
            private ubyte[] _data;
            private Tuple!(const(char)[], "key", Fghj, "value") _front;

            auto save() pure @property
            {
                return this;
            }

            void popFront() pure
            {
                while(!_data.empty)
                {
                    enforceValidFghj(_data.length > 1, Kind.object);
                    size_t l = cast(ubyte) _data[0];
                    _data.popFront;
                    enforceValidFghj(_data.length >= l, Kind.object);
                    _front.key = cast(const(char)[])_data[0 .. l];
                    _data.popFrontExactly(l);
                    uint t = cast(ubyte) _data.front;
                    switch(t)
                    {
                        case Kind.null_:
                        case Kind.true_:
                        case Kind.false_:
                            _front.value = Fghj(_data[0 .. 1]);
                            _data.popFront;
                            return;
                        case Kind.number:
                            enforceValidFghj(_data.length >= 2, t);
                            size_t len = _data[1] + 2;
                            enforceValidFghj(_data.length >= len, t);
                            _front.value = Fghj(_data[0 .. len]);
                            _data = _data[len .. $];
                            return;
                        case Kind.string:
                        case Kind.array:
                        case Kind.object:
                            enforceValidFghj(_data.length >= 5, t);
                            size_t len = Fghj(_data).length4 + 5;
                            enforceValidFghj(_data.length >= len, t);
                            _front.value = Fghj(_data[0 .. len]);
                            _data = _data[len .. $];
                            return;
                        case 0x80 | Kind.null_:
                        case 0x80 | Kind.true_:
                        case 0x80 | Kind.false_:
                            _data.popFront;
                            continue;
                        case 0x80 | Kind.number:
                            enforceValidFghj(_data.length >= 2, t);
                            _data.popFrontExactly(_data[1] + 2);
                            continue;
                        case 0x80 | Kind.string:
                        case 0x80 | Kind.array:
                        case 0x80 | Kind.object:
                            enforceValidFghj(_data.length >= 5, t);
                            size_t len = Fghj(_data).length4 + 5;
                            _data.popFrontExactly(len);
                            continue;
                        default:
                            enforceValidFghj(0, t);
                    }
                }
                _front = _front.init;
            }

            auto front() pure @property
            {
                assert(!empty);
                return _front;
            }

            bool empty() pure @property
            {
                return _front.value.data.length == 0;
            }
        }
        if(data.empty || data[0] != Kind.object)
            return Range.init;
        enforceValidFghj(data.length >= 5, Kind.object);
        enforceValidFghj(length4 == data.length - 5, Kind.object);
        auto ret = Range(data[5 .. $]);
        if(ret._data.length)
            ret.popFront;
        return ret;
    }

    /// returns 4-byte length
    private size_t length4() const @property pure nothrow @nogc @trusted
    {
        assert(data.length >= 5);
        version(X86_Any)
        {
            return (cast(uint*)(data.ptr + 1))[0];
        }
        else
        {
            align(4) auto ret = *cast(ubyte[4]*)(data.ptr + 1);
            return (cast(uint[1])ret)[0];
        }
    }

    /// ditto
    private void length4(size_t len) const @property pure nothrow @nogc @trusted
    {
        assert(data.length >= 5);
        assert(len <= uint.max);
        version(X86_Any)
        {
            *(cast(uint*)(data.ptr + 1)) = cast(uint) len;
        }
        else
        {
            *(cast(ubyte[4]*)(data.ptr + 1)) = cast(ubyte[4]) cast(uint[1]) [cast(uint) len];
        }
    }

    /++
    Searches for a value recursively in an FGHJ object.

    Params:
        keys = list of keys keys
    Returns
        FGHJ value if it was found (first win) or FGHJ with empty plain data.
    +/
    Fghj opIndex(in char[][] keys...) pure
    {
        auto fghj = this;
        if(fghj.data.empty)
            return Fghj.init;
        L: foreach(key; keys)
        {
            if(fghj.data[0] != Fghj.Kind.object)
                return Fghj.init;
            foreach(e; fghj.byKeyValue)
            {
                if(e.key == key)
                {
                    fghj = e.value;
                    continue L;
                }
            }
            return Fghj.init;
        }
        return fghj;
    }

    ///
    unittest
    {
        import fghj.jsonparser;
        auto fghjData = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`.parseJson;
        assert(fghjData["inner", "a"] == true);
        assert(fghjData["inner", "b"] == false);
        assert(fghjData["inner", "c"] == "32323");
        assert(fghjData["inner", "d"] == null);
        assert(fghjData["no", "such", "keys"] == Fghj.init);
    }

    /++
    Params:
        def = default value. It is used when FGHJ value equals `Fghj.init`.
    Returns:
        `cast(T) this` if `this != Fghj.init` and `def` otherwise.
    +/
    T get(T)(T def)
    {
        if(data.length)
        {
            return cast(T) this;
        }
        return def;
    }

    ///
    unittest
    {
        import fghj.jsonparser;
        auto fghjData = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`.parseJson;
        assert(fghjData["inner", "a"].get(false) == true);
        assert(fghjData["inner", "b"].get(true) == false);
        assert(fghjData["inner", "c"].get(100) == 32323);
        assert(fghjData["no", "such", "keys"].get(100) == 100);
    }

    /++
    `cast` operator overloading.
    +/
    T opCast(T)()
    {
        import std.datetime: SysTime, DateTime, usecs, UTC;
        import std.traits: isNumeric;
        import mir.conv: to;
        import std.conv: ConvException;
        import std.format: format;
        import std.math: trunc;
        import fghj.serialization;
        auto k = kind;
        with(Kind) switch(kind)
        {
            case null_ :
                static if (isNumeric!T
                        || is(T == interface)
                        || is(T == class)
                        || is(T == E[], E)
                        || is(T == E[K], E, K)
                        || is(T == bool))
                    return T.init;
                else goto default;
            case true_ :
                static if(__traits(compiles, true.to!T))
                    return true.to!T;
                else goto default;
            case false_:
                static if(__traits(compiles, false.to!T))
                    return false.to!T;
                else goto default;
            case number:
            {
                auto str = cast(const(char)[]) data[2 .. $];
                static if(is(T == bool))
                    return assumePure(() => str.to!double)() != 0;
                else
                static if(is(T == SysTime) || is(T == DateTime))
                {
                    auto unixTime = assumePure(() => str.to!real)();
                    auto secsR = assumePure(() => unixTime.trunc)();
                    auto rem = unixTime - secsR;
                    auto st = SysTime.fromUnixTime(cast(long)(secsR), UTC());
                    assumePure((ref SysTime st) => st.fracSecs = usecs(cast(long)(rem * 1_000_000)))(st);
                    return assumePure(() => st.to!T)();
                }
                else
                static if(__traits(compiles, assumePure(() => str.to!T)()))
                    return assumePure(() => str.to!T)();
                else goto default;
            }
            case string:
            {
                auto str = cast(const(char)[]) data[5 .. $];
                static if(is(T == bool))
                    return str != "0" && str != "false" && str != "";
                else
                static if(__traits(compiles, str.to!T))
                    return str.to!T;
                else goto default;
            }
            static if (isAggregateType!T || isArray!T)
            {
            case array :
            case object:
                static if(__traits(compiles, {T t = deserialize!T(this);}))
                    return deserialize!T(this);
                else goto default;
            }
            default:
                throw new ConvException(format("Cannot convert kind %s(\\x%02X) to %s", cast(Kind) k, k, T.stringof));
        }
    }

    /// null
    unittest
    {
        import std.math;
        import fghj.serialization;
        auto null_ = serializeToFghj(null);
        interface I {}
        class C {}
        assert(cast(uint[]) null_ is null);
        assert(cast(uint[uint]) null_ is null);
        assert(cast(I) null_ is null);
        assert(cast(C) null_ is null);
        assert(isNaN(cast(double) null_));
        assert(! cast(bool) null_);
    }

    /// boolean
    unittest
    {
        import std.math;
        import fghj.serialization;
        auto true_ = serializeToFghj(true);
        auto false_ = serializeToFghj(false);
        static struct C {
            this(bool){}
        }
        auto a = cast(C) true_;
        auto b = cast(C) false_;
        assert(cast(bool) true_ == true);
        assert(cast(bool) false_ == false);
        assert(cast(uint) true_ == 1);
        assert(cast(uint) false_ == 0);
        assert(cast(double) true_ == 1);
        assert(cast(double) false_ == 0);
    }

    /// numbers
    unittest
    {
        import std.bigint;
        import fghj.serialization;
        auto number = serializeToFghj(1234);
        auto zero = serializeToFghj(0);
        static struct C
        {
            this(in char[] numberString)
            {
                assert(numberString == "1234");
            }
        }
        auto a = cast(C) number;
        assert(cast(bool) number == true);
        assert(cast(bool) zero == false);
        assert(cast(uint) number == 1234);
        assert(cast(double) number == 1234);
        assert(cast(BigInt) number == 1234);
        assert(cast(uint) zero == 0);
        assert(cast(double) zero == 0);
        assert(cast(BigInt) zero == 0);
    }

    /// string
    unittest
    {
        import std.bigint;
        import fghj.serialization;
        auto number = serializeToFghj("1234");
        auto false_ = serializeToFghj("false");
        auto bar = serializeToFghj("bar");
        auto zero = serializeToFghj("0");
        static struct C
        {
            this(in char[] str)
            {
                assert(str == "1234");
            }
        }
        auto a = cast(C) number;
        assert(cast(string) number == "1234");
        assert(cast(bool) number == true);
        assert(cast(bool) bar == true);
        assert(cast(bool) zero == false);
        assert(cast(bool) false_ == false);
        assert(cast(uint) number == 1234);
        assert(cast(double) number == 1234);
        assert(cast(BigInt) number == 1234);
        assert(cast(uint) zero == 0);
        assert(cast(double) zero == 0);
        assert(cast(BigInt) zero == 0);
    }

    /++
    For FGHJ arrays and objects `cast(T)` just returns `this.deserialize!T`.
    +/
    unittest
    {
        import std.bigint;
        import fghj.serialization;
        assert(cast(int[]) serializeToFghj([100, 20]) == [100, 20]);
    }

    /// UNIX Time
    unittest
    {
        import std.datetime;
        import fghj.serialization;

        auto num = serializeToFghj(0.123456789); // rounding up to usecs
        assert(cast(DateTime) num == DateTime(1970, 1, 1));
        assert(cast(SysTime) num == SysTime(DateTime(1970, 1, 1), usecs(123456), UTC())); // UTC time zone is used.
    }
}
