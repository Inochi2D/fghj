
import std.stdio;
import std.exception;

import fghj;

int main(string[] args)
{
	if(args.length < 2)
	{
		writeln("Usage: test_json-fghj <input_filname>.");
		return -1;
	}
	auto filename = args[1];
	try
	{
		auto fghj = File(filename)
			.byChunk(4096)
			.parseJson();
	}
	catch(Exception e)
	{
		return 1;
	}
	return 0;
}
