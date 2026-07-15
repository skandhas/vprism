module vprism

import os
import vprism.ffi

// prism_version returns the version reported by the bundled Prism C library.
pub fn prism_version() string {
	return ffi.prism_version()
}

// dump_json parses Ruby source and returns Prism's JSON AST dump.
pub fn dump_json(source string) !string {
	return ffi.dump_json(source)
}

// dump_json_with_options parses Ruby source and returns Prism's JSON AST dump with parser options.
pub fn dump_json_with_options(source string, options ParseOptions) !string {
	serialized_options := options.serialize()!

	return ffi.dump_json_with_options(source, serialized_options)
}

// dump_json_file reads a Ruby file and returns Prism's JSON AST dump.
pub fn dump_json_file(path string) !string {
	return dump_json_file_with_options(path, ParseOptions{})
}

// dump_json_file_with_options reads a Ruby file and returns Prism's JSON AST dump with parser options.
pub fn dump_json_file_with_options(path string, options ParseOptions) !string {
	source := os.read_file(path)!
	serialized_options := options.serialize_with_filepath(path)!

	return ffi.dump_json_with_options(source, serialized_options)
}

// prettyprint parses Ruby source and returns Prism's pretty-printed AST.
pub fn prettyprint(source string) !string {
	return ffi.prettyprint(source)
}

// prettyprint_with_options parses Ruby source and returns Prism's pretty-printed AST with parser options.
pub fn prettyprint_with_options(source string, options ParseOptions) !string {
	serialized_options := options.serialize()!

	return ffi.prettyprint_with_options(source, serialized_options)
}

// prettyprint_file reads a Ruby file and returns Prism's pretty-printed AST.
pub fn prettyprint_file(path string) !string {
	return prettyprint_file_with_options(path, ParseOptions{})
}

// prettyprint_file_with_options reads a Ruby file and returns Prism's pretty-printed AST with parser options.
pub fn prettyprint_file_with_options(path string, options ParseOptions) !string {
	source := os.read_file(path)!
	serialized_options := options.serialize_with_filepath(path)!

	return ffi.prettyprint_with_options(source, serialized_options)
}
