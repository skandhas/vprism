module main

import os
import vprism

// main parses the Ruby file provided on the command line.
fn main() {
	if os.args.len < 2 {
		eprintln('usage: parse_file <file.rb>')
		exit(1)
	}

	result := vprism.parse_file(os.args[1])!

	println(result.root)
}
