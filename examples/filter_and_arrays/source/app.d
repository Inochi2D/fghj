import std.algorithm;
import std.stdio;
import fghj;

void main()
{
	auto target = Fghj("red");
	File("input.jsonl")
		.byChunk(10)                  // Use at least 4096 bytes for real world apps
		.parseJsonByLine
		.filter!(object => object["colors"]
			.byElement                // iterates over an array
			.canFind(target))         // Comparison with FGHJ is little bit faster than
			//.canFind("tadmp5800"))  //    comparison with a string.
		.each!writeln;                // See also `lockingTextWriter` from `std.stdio`.
}
