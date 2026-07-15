module vprism

import os
import vprism.ffi
import vprism.serialize

// Token describes one Ruby lexer token returned by Prism.
pub type Token = serialize.Token

// LexResult contains Prism lexer tokens and parser metadata.
pub type LexResult = serialize.LexResult

// ParseLexResult contains both lexer tokens and the decoded AST from Prism.
pub type ParseLexResult = serialize.ParseLexResult

// lex lexes Ruby source with Prism and returns tokens plus metadata.
pub fn lex(source string) !LexResult {
	data := ffi.serialize_lex(source)!

	return LexResult(serialize.decode_lex(source, data)!)
}

// lex_with_options lexes Ruby source with Prism parser options.
pub fn lex_with_options(source string, options ParseOptions) !LexResult {
	serialized_options := options.serialize()!
	data := ffi.serialize_lex_with_options(source, serialized_options)!

	return LexResult(serialize.decode_lex(source, data)!)
}

// lex_file reads and lexes a Ruby source file with its path as the Prism filepath.
pub fn lex_file(path string) !LexResult {
	return lex_file_with_options(path, ParseOptions{})
}

// lex_file_with_options reads and lexes a Ruby file with parser options.
pub fn lex_file_with_options(path string, options ParseOptions) !LexResult {
	source := os.read_file(path)!
	serialized_options := options.serialize_with_filepath(path)!
	data := ffi.serialize_lex_with_options(source, serialized_options)!

	return LexResult(serialize.decode_lex(source, data)!)
}

// parse_lex parses and lexes Ruby source with Prism in one native call.
pub fn parse_lex(source string) !ParseLexResult {
	data := ffi.serialize_parse_lex(source)!

	return ParseLexResult(serialize.decode_parse_lex(source, data)!)
}

// parse_lex_with_options parses and lexes Ruby source with parser options.
pub fn parse_lex_with_options(source string, options ParseOptions) !ParseLexResult {
	serialized_options := options.serialize()!
	data := ffi.serialize_parse_lex_with_options(source, serialized_options)!

	return ParseLexResult(serialize.decode_parse_lex(source, data)!)
}

// parse_lex_file reads, parses, and lexes a Ruby source file.
pub fn parse_lex_file(path string) !ParseLexResult {
	return parse_lex_file_with_options(path, ParseOptions{})
}

// parse_lex_file_with_options reads, parses, and lexes a Ruby file with parser options.
pub fn parse_lex_file_with_options(path string, options ParseOptions) !ParseLexResult {
	source := os.read_file(path)!
	serialized_options := options.serialize_with_filepath(path)!
	data := ffi.serialize_parse_lex_with_options(source, serialized_options)!

	return ParseLexResult(serialize.decode_parse_lex(source, data)!)
}
