module main

import os
import vprism

// main parses a Ruby file through Prism's stream parser.
fn main() {
	if os.args.len < 2 {
		eprintln('usage: parse_stream_file <file.rb>')
		exit(1)
	}

	result := vprism.parse_stream_file(os.args[1])!

	println(result.root)
	println('errors: ${result.metadata.errors.len}')
}
