module main

import os
import vprism

// main prints Prism's pretty-printed AST for a Ruby file.
fn main() {
	if os.args.len < 2 {
		eprintln('usage: prettyprint <file.rb>')
		exit(1)
	}

	println(vprism.prettyprint_file(os.args[1])!)
}
