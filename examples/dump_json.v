module main

import os
import vprism

// main prints Prism's JSON AST dump for a Ruby file.
fn main() {
	if os.args.len < 2 {
		eprintln('usage: dump_json <file.rb>')
		exit(1)
	}

	println(vprism.dump_json_file(os.args[1])!)
}
