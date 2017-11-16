import std.algorithm;
import std.stdio;
import asdf;

void main()
{
	auto target = Asdf("red");
	File("input.jsonl")
		.byChunk(10)                  // Use at least 4096 bytes for real wolrd apps
		.parseJsonByLine
		.filter!(object => object["colors"]
			.byElement                // iterates over an array
			.canFind(target))         // Comparison with ASDF is little bit faster then
			//.canFind("tadmp5800"))  //    compression with a string.
		.each!writeln;                // See also `lockingTextWriter` from `std.stdio`.
}
