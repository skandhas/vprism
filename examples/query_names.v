module main

import os
import vprism

// main checks Ruby local, constant, and method name validity.
fn main() {
	if os.args.len < 2 {
		eprintln('usage: query_names <name> [name...]')
		exit(1)
	}

	for name in os.args[1..] {
		local := vprism.is_local_name(name)!
		constant := vprism.is_constant_name(name)!
		method := vprism.is_method_name(name)!

		println('${name}: local=${local} constant=${constant} method=${method}')
	}
}
