module main

import vprism

// main parses a small Ruby snippet and prints the AST root.
fn main() {
	result := vprism.parse('puts "hello"')!
	println(result.root)
}
