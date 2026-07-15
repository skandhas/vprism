module vprism

import os
import vprism.ffi
import vprism.serialize

// ParseResult contains the decoded Prism parse result and strongly typed AST.
pub type ParseResult = serialize.ParseResult

// parse parses Ruby source with Prism and returns a parsed serialized AST result.
pub fn parse(source string) !ParseResult {
	data := ffi.serialize_parse(source)!

	return ParseResult(serialize.decode_parse(source, data)!)
}

// parse_with_options parses Ruby source with Prism parser options.
pub fn parse_with_options(source string, options ParseOptions) !ParseResult {
	serialized_options := options.serialize()!
	data := ffi.serialize_parse_with_options(source, serialized_options)!

	return ParseResult(serialize.decode_parse(source, data)!)
}

// parse_file reads and parses a Ruby source file with its path as the Prism filepath.
pub fn parse_file(path string) !ParseResult {
	return parse_file_with_options(path, ParseOptions{})
}

// parse_file_with_options reads and parses a Ruby file with parser options.
pub fn parse_file_with_options(path string, options ParseOptions) !ParseResult {
	source := os.read_file(path)!
	serialized_options := options.serialize_with_filepath(path)!
	data := ffi.serialize_parse_with_options(source, serialized_options)!

	return ParseResult(serialize.decode_parse(source, data)!)
}

// parse_stream_file parses a Ruby source file with Prism's stream parser.
pub fn parse_stream_file(path string) !ParseResult {
	return parse_stream_file_with_options(path, ParseOptions{})
}

// parse_stream_file_with_options parses a Ruby file with Prism's stream parser and parser options.
pub fn parse_stream_file_with_options(path string, options ParseOptions) !ParseResult {
	source := os.read_file(path)!
	serialized_options := options.serialize_with_filepath(path)!
	data := ffi.serialize_parse_stream_file(path, serialized_options)!

	return ParseResult(serialize.decode_parse(source, data)!)
}

// is_valid checks whether Ruby source parses successfully without decoding the AST.
pub fn is_valid(source string) !bool {
	return ffi.parse_success(source)
}

// is_valid_with_options checks whether Ruby source parses successfully with parser options.
pub fn is_valid_with_options(source string, options ParseOptions) !bool {
	serialized_options := options.serialize()!

	return ffi.parse_success_with_options(source, serialized_options)
}

// is_valid_file reads a Ruby source file and checks whether it parses successfully.
pub fn is_valid_file(path string) !bool {
	return is_valid_file_with_options(path, ParseOptions{})
}

// is_valid_file_with_options reads a Ruby file and checks whether it parses successfully.
pub fn is_valid_file_with_options(path string, options ParseOptions) !bool {
	source := os.read_file(path)!
	serialized_options := options.serialize_with_filepath(path)!

	return ffi.parse_success_with_options(source, serialized_options)
}
