/++
$(H2 ASDF Package)

Publicly imports $(SUBMODULE asdf) and $(SUBMODULE jsonparser).

Copyright: Tamedia Digital, 2016

Authors: Ilya Yaroshenko

License: MIT

Macros:
SUBMODULE = $(LINK2 asdf_$1.html, asdf.$1)
SUBREF = $(LINK2 asdf_$1.html#.$2, $(TT $2))$(NBSP)
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
T4=$(TR $(TDNW $(LREF $1)) $(TD $2) $(TD $3) $(TD $4))
+/
module asdf;

public import asdf.asdf;
public import asdf.jsonparser;


unittest
{
	import std.conv: to;
	import std.range;
	auto text = cast(const ubyte[])`{"a":[true],"b":false,"c":32323,"dsdsd":{"a":true,"b":false,"c":"32323","d":null,"dsdsd":{}}}`;
	auto asdf = text.chunks(13).parseJson(32);
	import std.stdio;
	assert(asdf.getValue(["dsdsd", "d"]) == null);
	assert(asdf.getValue(["dsdsd", "a"]) == true);
	assert(asdf.getValue(["dsdsd", "b"]) == false);
	assert(asdf.getValue(["dsdsd", "c"]) == "32323");
	assert(asdf.to!string == text);
}


//unittest
//{
//	import std.datetime;
//	import std.conv;
//	import std.stdio;
//	import std.format;
//	auto values = File("lines.jsonl").byChunk(4096).parseAsdfByLine(4096);
//	size_t len, count;
//	FormatSpec!char fmt;
//	auto wr = stdout.lockingTextWriter;
//	foreach(val; values)
//	{
//		len += val.data.length;
//		if(val.getValue(["dsrc"]) == "20min.ch")
//		{
//			count++;
//			wr.formatValue(val, fmt);
//			wr.put("\n");
//		}
//	}
//}