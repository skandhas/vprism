module vprism

import os
import vprism.ffi
import vprism.serialize

// CommentsResult contains comments parsed by Prism without decoding the full AST.
pub struct CommentsResult {
pub:
	// source is the original Ruby source used for comment text lookups.
	source string

	// header is the decoded Prism serialization header.
	header serialize.Header

	// encoding is the source encoding name.
	encoding string

	// start_line is the source start line configured on the parser.
	start_line i32

	// comments contains serialized Ruby comments in source order.
	comments []serialize.Comment
}

// text returns the source text covered by a comment.
pub fn (result CommentsResult) text(comment serialize.Comment) !string {
	return serialize.source_slice(result.source, comment.location)
}

// parse_comments parses only Ruby comments through Prism.
pub fn parse_comments(source string) !CommentsResult {
	data := ffi.serialize_parse_comments(source)!

	return decode_comments(source, data)
}

// parse_comments_with_options parses only Ruby comments through Prism with parser options.
pub fn parse_comments_with_options(source string, options ParseOptions) !CommentsResult {
	serialized_options := options.serialize()!
	data := ffi.serialize_parse_comments_with_options(source, serialized_options)!

	return decode_comments(source, data)
}

// parse_comments_file reads a Ruby source file and parses only its comments.
pub fn parse_comments_file(path string) !CommentsResult {
	return parse_comments_file_with_options(path, ParseOptions{})
}

// parse_comments_file_with_options reads a Ruby file and parses only its comments with parser options.
pub fn parse_comments_file_with_options(path string, options ParseOptions) !CommentsResult {
	source := os.read_file(path)!
	serialized_options := options.serialize_with_filepath(path)!
	data := ffi.serialize_parse_comments_with_options(source, serialized_options)!

	return decode_comments(source, data)
}

// decode_comments decodes Prism serialized parse_comments bytes.
fn decode_comments(source string, data []u8) !CommentsResult {
	mut reader := serialize.Reader.new(data)
	header := serialize.read_header(mut reader)!
	encoding := reader.read_string()!
	start_line := reader.read_varsint()!
	comments := serialize.read_comments(mut reader)!

	if reader.remaining() != 0 {
		return error('serialized comments result has trailing bytes')
	}

	return CommentsResult{
		source:     source
		header:     header
		encoding:   encoding
		start_line: start_line
		comments:   comments
	}
}
