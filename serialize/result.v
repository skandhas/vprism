module serialize

import vprism.ast

// ParseResult contains the decoded Prism serialization header and metadata.
pub struct ParseResult {
pub:
	// source is the original Ruby source used by locations and shared strings.
	source string

	// header is the decoded Prism serialization header.
	header Header

	// metadata contains source-level data before the root node.
	metadata Metadata

	// constant_pool describes the serialized constant pool trailer.
	constant_pool ConstantPool

	// root is the decoded strongly typed root AST node.
	root ast.Node

	// root_node_type is the first byte of the serialized root node.
	root_node_type u8

	// root_node_offset is the byte offset where the root node starts.
	root_node_offset int
}

// source_text returns the source bytes covered by a Prism location.
pub fn (result ParseResult) source_text(location ast.Location) !string {
	start := u64(location.start_offset)
	length := u64(location.length)
	end := start + length

	if end > u64(result.source.len) {
		return error('location is outside source')
	}

	return result.source.bytes()[int(start)..int(end)].bytestr()
}

// node_text returns the source bytes covered by a decoded node location.
pub fn (result ParseResult) node_text(node ast.Node) !string {
	return result.source_text(node.base().location)
}

// constant_value returns the source or owned value for a constant id.
pub fn (result ParseResult) constant_value(id ast.ConstantId) !string {
	return result.constant_pool.value(result.source, id)
}

// constant_values returns decoded string values for constant ids.
pub fn (result ParseResult) constant_values(constant_ids []ast.ConstantId) ![]string {
	mut values := []string{cap: constant_ids.len}

	for constant_id in constant_ids {
		values << result.constant_value(constant_id)!
	}

	return values
}

// find_first returns the first node with kind under the root node.
pub fn (result ParseResult) find_first(kind ast.NodeKind) ?ast.Node {
	return result.root.find_first(kind)
}

// find_all returns all nodes with kind under the root node.
pub fn (result ParseResult) find_all(kind ast.NodeKind) []ast.Node {
	return result.root.find_all(kind)
}

// walk calls visitor for the root node and every descendant.
pub fn (result ParseResult) walk(mut visitor ast.Visitor) ! {
	result.root.walk(mut visitor)!
}

// Header describes the fixed Prism serialization header.
pub struct Header {
pub:
	// version is the Prism serialization version.
	version FormatVersion

	// semantics_only is true when location fields were omitted.
	semantics_only bool
}

// Metadata contains serialized parser metadata before the root node.
pub struct Metadata {
pub:
	// encoding is the source encoding name.
	encoding string

	// start_line is the source start line configured on the parser.
	start_line i32

	// newline_offsets contains byte offsets for newlines in the source.
	newline_offsets []u32

	// comments contains serialized source comments.
	comments []Comment

	// magic_comments contains serialized magic comments.
	magic_comments []MagicComment

	// data_loc is the optional __END__ marker location.
	data_loc OptionalLocation

	// errors contains serialized parser errors.
	errors []Diagnostic

	// warnings contains serialized parser warnings.
	warnings []Diagnostic
}

// CommentKind identifies a serialized Ruby comment type.
pub enum CommentKind {
	inline
	embdoc
}

// Comment contains a serialized Ruby source comment.
pub struct Comment {
pub:
	// kind identifies the comment shape.
	kind CommentKind

	// location points to the comment bytes in the source.
	location ast.Location
}

// MagicComment contains key and value locations for a Ruby magic comment.
pub struct MagicComment {
pub:
	// key_loc points to the magic comment key.
	key_loc ast.Location

	// value_loc points to the magic comment value.
	value_loc ast.Location
}

// DiagnosticLevel stores Prism diagnostic severity or warning level.
pub type DiagnosticLevel = u8

// ErrorLevel identifies the Ruby exception class for parser errors.
pub enum ErrorLevel {
	syntax
	argument
	load
}

// WarningLevel identifies the visibility level for parser warnings.
pub enum WarningLevel {
	default_
	verbose
}

// Diagnostic contains a serialized parser diagnostic.
pub struct Diagnostic {
pub:
	// kind identifies the Prism diagnostic.
	kind DiagnosticKind

	// message is the diagnostic message.
	message string

	// location points to the source range for this diagnostic.
	location ast.Location

	// level is the numeric Prism diagnostic level.
	level DiagnosticLevel
}

// is_error reports whether this diagnostic is a Prism parser error.
pub fn (diagnostic Diagnostic) is_error() bool {
	return diagnostic.kind.is_error()
}

// is_warning reports whether this diagnostic is a Prism parser warning.
pub fn (diagnostic Diagnostic) is_warning() bool {
	return diagnostic.kind.is_warning()
}

// error_level returns this diagnostic level as a Prism parser error level.
pub fn (diagnostic Diagnostic) error_level() !ErrorLevel {
	return diagnostic.level.error_level()
}

// warning_level returns this diagnostic level as a Prism parser warning level.
pub fn (diagnostic Diagnostic) warning_level() !WarningLevel {
	return diagnostic.level.warning_level()
}

// error_level converts a numeric diagnostic level to an error level.
pub fn (level DiagnosticLevel) error_level() !ErrorLevel {
	return match u8(level) {
		0 { .syntax }
		1 { .argument }
		2 { .load }
		else { error('unknown Prism error level: ${u8(level)}') }
	}
}

// warning_level converts a numeric diagnostic level to a warning level.
pub fn (level DiagnosticLevel) warning_level() !WarningLevel {
	return match u8(level) {
		0 { .default_ }
		1 { .verbose }
		else { error('unknown Prism warning level: ${u8(level)}') }
	}
}
