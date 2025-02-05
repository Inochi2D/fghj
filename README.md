[![Dub version](https://img.shields.io/dub/v/fghj.svg)](http://code.dlang.org/packages/fghj)
[![Dub downloads](https://img.shields.io/dub/dt/fghj.svg)](http://code.dlang.org/packages/fghj)
[![License](https://img.shields.io/dub/l/fghj.svg)](http://code.dlang.org/packages/fghj)

# Fox Girl Handles JSON

_**!! This is a fork of the defunct Asdf library, meant for use with Inochi2D. !!**_

FGHJ is a cache oriented string based JSON representation.
Besides, it is a convenient Json Library for D that gets out of your way.
FGHJ is specially geared towards transforming high volumes of JSON dataframes, either to new 
JSON Objects or to custom data types.

#### Why FGHJ?

fghj was originally developed at [Tamedia](https://www.tamedia.ch/) to extract and transform real-time click streams.

- FGHJ is fast. It can be really helpful if you have gigabytes of JSON line separated values.
- FGHJ is simple. It uses D's modelling power to make you write less boilerplate code.
- FGHJ is tested and used in production for real World JSON generated by millions of web clients (we call it _the great fuzzer_).

see also [github.com/tamediadigital/je](https://github.com/tamediadigital/je) a tool for fast extraction of json properties into a csv/tsv.

#### Simple Example

1. define your struct
2. call `serializeToJson` ( or `serializeToJsonPretty` for pretty printing! )
3. profit! 

```D
/+dub.sdl:
dependency "fghj" version="~>0.2.5"

#turns on SSE4.2 optimizations when compiled with LDC
dflags "-mattr=+sse4.2" platform="ldc"
+/
import fghj;

struct Simple
{
    string name;
    ulong level;
}

void main()
{
    auto o = Simple("fghj", 42);
    string data = `{"name":"fghj","level":42}`;
    assert(o.serializeToJson() == data);
    assert(data.deserialize!Simple == o);
}
```
#### Documentation

See FGHJ [API](http://fghj.libmir.org) and [Specification](https://github.com/tamediadigital/fghj/blob/master/SPECIFICATION.md).

#### I/O Speed

 - Reading JSON line separated values and parsing them to FGHJ - 300+ MB per second (SSD).
 - Writing FGHJ range to JSON line separated values - 300+ MB per second (SSD).

#### Fast setup with the dub package manager

[![Dub version](https://img.shields.io/dub/v/fghj.svg)](http://code.dlang.org/packages/fghj)

[Dub](https://code.dlang.org/getting_started) is D's package manager.
You can create a new project with:

```
dub init <project-name>
```

Now you need to edit the `dub.json` add `fghj` as dependency and set its targetType to `executable`.

(dub.json)
```json
{
    ...
    "dependencies": {
        "fghj": "~><current-version>"
    },
    "targetType": "executable",
    "dflags-ldc": ["-mcpu=native"]
}
```

(dub.sdl)
```sdl
dependency "fghj" version="~><current-version>"
targetType "executable"
dflags "-mcpu=native" platform="ldc"
```

Now you can create a main file in the `source` and run your code with 
```
dub
```
Flags `--build=release` and `--compiler=ldmd2` can be added for a performance boost:
```
dub --build=release --compiler=ldmd2
```

`ldmd2` is a shell on top of [LDC (LLVM D Compiler)](https://github.com/ldc-developers/ldc).
`"dflags-ldc": ["-mcpu=native"]` allows LDC to optimize FGHJ for your CPU.

Instead of using `-mcpu=native`, you may specify an additional instruction set for a target with `-mattr`.
For example, `-mattr=+sse4.2`. FGHJ has specialized code for
[SSE4.2](https://en.wikipedia.org/wiki/SSE4#SSE4.2 instruction set).

#### Main transformation functions

| uda | function |
| ------------- |:-------------:|
| `@serdeKeys("bar_common", "bar")` | tries to read the data from either property. saves it to the first one |
| `@serdeKeysIn("a", "b")` | tries to read the data from `a`, then `b`. last one occuring in the json wins |
| `@serdeKeyOut("a")` | writes it to `a` |
| `@serdeIgnore` | ignore this property completely |
| `@serdeIgnoreIn` | don't read this property |
| `@serdeIgnoreOut` | don't write this property |
| `@serdeIgnoreOutIf!condition` | run function `condition` on serialization and don't write this property if the result is true |
| `@serdeScoped` | Dangerous! non allocating strings. this means data can vanish if the underlying buffer is removed.  |
| `@serdeProxy!string` | call to!string |
| `@serdeTransformIn!fin` | call function `fin` to transform the data |
| `@serdeTransformOut!fout`  | run function `fout` on serialization, different notation |
| `@serdeAllowMultiple`  | Allows deserialiser to serialize multiple keys for the same object member input. |
| `@serdeOptional`  | Allows deserialiser to to skip member desrization of no keys corresponding keys input. |


Please also look into the Docs or Unittest for concrete examples!

#### FGHJ Example (incomplete)

```D
import std.algorithm;
import std.stdio;
import fghj;

void main()
{
    auto target = Fghj("red");
    File("input.jsonl")
        // Use at least 4096 bytes for real world apps
        .byChunk(4096)
        // 32 is minimum size for internal buffer. Buffer can be reallocated to get more memory.
        .parseJsonByLine(4096)
        .filter!(object => object
            // opIndex accepts array of keys: {"key0": {"key1": { ... {"keyN-1": <value>}... }}}
            ["colors"]
            // iterates over an array
            .byElement
            // Comparison with FGHJ is little bit faster
            //   than comparison with a string.
            .canFind(target))
            //.canFind("red"))
        // Formatting uses internal buffer to reduce system delegate and system function calls
        .each!writeln;
}
```

##### Input

Single object per line: 4th and 5th lines are broken.

```json
null
{"colors": ["red"]}
{"a":"b", "colors": [4, "red", "string"]}
{"colors":["red"],
    "comment" : "this is broken (multiline) object"}
{"colors": "green"}
{"colors": "red"]}}
[]
```

##### Output

```json
{"colors":["red"]}
{"a":"b","colors":[4,"red","string"]}
```


#### JSON and FGHJ Serialization Examples

##### Simple struct or object
```d
struct S
{
    string a;
    long b;
    private int c; // private fields are ignored
    package int d; // package fields are ignored
    // all other fields in JSON are ignored
}
```

##### Selection
```d
struct S
{
    // ignored
    @serdeIgnore int temp;
    
    // can be formatted to json
    @serdeIgnoreIn int a;
    
    //can be parsed from json
    @serdeIgnoreOut int b;
    
    // ignored if negative
    @serdeIgnoreOutIf!`a < 0` int c;
}
```

##### Key overriding
```d
struct S
{
    // key is overrided to "aaa"
    @serdeKeys("aaa") int a;

    // overloads multiple keys for parsing
    @serdeKeysIn("b", "_b")
    // overloads key for generation
    @serdeKeyOut("_b_")
    int b;
}
```

##### User-Defined Serialization
```d
struct DateTimeProxy
{
    DateTime datetime;
    alias datetime this;

    SerdeException deserializeFromFghj(Fghj data)
    {
        string val;
        if (auto exc = deserializeScopedString(data, val))
            return exc;
        this = DateTimeProxy(DateTime.fromISOString(val));
        return null;
    }

    void serialize(S)(ref S serializer)
    {
        serializer.putValue(datetime.toISOString);
    }
}
```

```d
//serialize a Doubly Linked list into an Array
struct SomeDoublyLinkedList
{
    @serdeIgnore DList!(SomeArr[]) myDll;
    alias myDll this;

    //no template but a function this time!
    void serialize(ref FghjSerializer serializer)
    {
        auto state = serializer.listBegin();
        foreach (ref elem; myDll)
        {
            serializer.elemBegin;
            serializer.serializeValue(elem);
        }
        serializer.listEnd(state);
    }   
}
```

##### Serialization Proxy
```d
struct S
{
    @serdeProxy!DateTimeProxy DateTime time;
}
```

```d
@serdeProxy!ProxyE
enum E
{
    none,
    bar,
}

// const(char)[] doesn't reallocate FGHJ data.
@serdeProxy!(const(char)[])
struct ProxyE
{
    E e;

    this(E e)
    {
        this.e = e;
    }

    this(in char[] str)
    {
        switch(str)
        {
            case "NONE":
            case "NA":
            case "N/A":
                e = E.none;
                break;
            case "BAR":
            case "BR":
                e = E.bar;
                break;
            default:
                throw new Exception("Unknown: " ~ cast(string)str);
        }
    }

    string toString()
    {
        if (e == E.none)
            return "NONE";
        else
            return "BAR";
    }

    E opCast(T : E)()
    {
        return e;
    }
}

unittest
{
    assert(serializeToJson(E.bar) == `"BAR"`);
    assert(`"N/A"`.deserialize!E == E.none);
    assert(`"NA"`.deserialize!E == E.none);
}
```


##### Finalizer
If you need to do additional calculations or etl transformations that happen to depend on the deserialized data use the `finalizeDeserialization` method.

```d
struct S
{
    string a;
    int b;

    @serdeIgnoreIn double sum;

    void finalizeDeserialization(Fghj data)
    {
        auto r = data["c", "d"];
        auto a = r["e"].get(0.0);
        auto b = r["g"].get(0.0);
        sum = a + b;
    }
}
assert(`{"a":"bar","b":3,"c":{"d":{"e":6,"g":7}}}`.deserialize!S == S("bar", 3, 13));
```
