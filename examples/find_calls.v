module main

import os
import vprism
import vprism.analysis

// main prints call nodes from a Ruby file or a small built-in snippet.
fn main() {
	source := if os.args.len > 1 {
		os.read_file(os.args[1])!
	} else {
		'puts "hello"\nfoo(bar: 1)'
	}
	result := analysis.Analyzer.new(vprism.parse(source)!)

	for call in result.calls() {
		println('${call.name}: ${call.text}')
	}
}
