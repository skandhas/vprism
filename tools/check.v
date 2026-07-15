module main

import os

// checkStep describes one command in the package quality check.
struct CheckStep {
	name    string
	command string
}

// main runs the vprism package quality checks.
fn main() {
	root := package_root()!
	os.chdir(root)!
	os.setenv('VMODULES', os.join_path(root, '.vmodules'), true)

	quick := os.args.contains('--quick')
	mut steps := [
		CheckStep{
			name:    'format'
			command: 'v fmt -verify .'
		},
		CheckStep{
			name:    'tests'
			command: 'v test .'
		},
	]

	steps << example_steps()

	if !quick {
		steps << CheckStep{
			name:    'production tests'
			command: 'v -prod test .'
		}
	}

	for step in steps {
		run_step(step)!
	}

	println('vprism check passed')
}

// package_root returns the project root when the tool is run from the root or tools directory.
fn package_root() !string {
	cwd := os.getwd()

	if os.exists(os.join_path(cwd, 'v.mod')) {
		return cwd
	}

	parent := os.dir(cwd)
	if os.exists(os.join_path(parent, 'v.mod')) {
		return parent
	}

	return error('run tools/check.v from the vprism root or tools directory')
}

// example_steps returns commands that compile every checked example.
fn example_steps() []CheckStep {
	examples := [
		'examples/parse_file.v',
		'examples/parse_stream_file.v',
		'examples/print_ast.v',
		'examples/find_calls.v',
		'examples/dump_json.v',
		'examples/prettyprint.v',
		'examples/query_names.v',
	]
	mut steps := []CheckStep{cap: examples.len}

	for example in examples {
		steps << CheckStep{
			name:    'example ${example}'
			command: 'v ${example}'
		}
	}

	return steps
}

// run_step executes one check command and fails the tool when the command fails.
fn run_step(step CheckStep) ! {
	println('==> ${step.name}')
	result := os.execute(step.command)

	if result.exit_code != 0 {
		if result.output.len > 0 {
			eprintln(result.output)
		}

		return error('${step.name} failed with exit code ${result.exit_code}')
	}

	if result.output.len > 0 {
		print(result.output)
	}
}
