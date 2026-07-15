module serialize

const prism_magic = [u8(`P`), `R`, `I`, `S`, `M`]

// decode decodes Prism serialized AST bytes without original source context.
pub fn decode(data []u8) !ParseResult {
	return decode_parse('', data)
}

// decode_parse decodes Prism serialized AST bytes with their original Ruby source.
pub fn decode_parse(source string, data []u8) !ParseResult {
	return decode_parse_at(source, data, 0)
}

// decode_parse_at decodes Prism serialized AST bytes that start at an offset in a larger buffer.
pub fn decode_parse_at(source string, data []u8, start int) !ParseResult {
	if start < 0 || start > data.len {
		return error('serialized parse start is outside the buffer')
	}

	mut reader := new_reader(data)
	reader.read_bytes(start)!

	header := read_header(mut reader)!
	metadata := read_metadata(mut reader)!
	constant_pool_base := reader.read_u32_le()!
	constant_pool_size := reader.read_varuint()!

	root_node_offset := reader.position()
	root_node_type := reader.peek_u8()!
	root := decode_node(mut reader, source, ConstantPool{
		base: constant_pool_base
		size: constant_pool_size
	})!

	if reader.position() != int(constant_pool_base) {
		return error('root node did not end at constant pool base')
	}

	constant_pool := read_constant_pool(data, constant_pool_base, constant_pool_size)!

	return ParseResult{
		source:           source
		header:           header
		metadata:         metadata
		constant_pool:    constant_pool
		root:             root
		root_node_type:   root_node_type
		root_node_offset: root_node_offset
	}
}

// read_header reads Prism's fixed serialization header.
pub fn read_header(mut reader Reader) !Header {
	magic := reader.read_bytes(5)!

	if magic != prism_magic {
		return error('invalid Prism serialization magic')
	}

	version := FormatVersion{
		major: u32(reader.read_u8()!)
		minor: u32(reader.read_u8()!)
		patch: u32(reader.read_u8()!)
	}
	version.ensure_supported()!

	semantics_only := reader.read_u8()! != 0

	if semantics_only {
		return error('Prism serialization without location fields is not supported')
	}

	return Header{
		version:        version
		semantics_only: semantics_only
	}
}

// read_metadata reads parser metadata from Prism serialized bytes.
pub fn read_metadata(mut reader Reader) !Metadata {
	encoding := reader.read_string()!
	start_line := reader.read_varsint()!

	newline_offsets := read_varuint_list(mut reader)!
	comments := read_comments(mut reader)!
	magic_comments := read_magic_comments(mut reader)!
	data_loc := reader.read_optional_location()!
	errors := read_diagnostics(mut reader)!
	warnings := read_diagnostics(mut reader)!

	return Metadata{
		encoding:        encoding
		start_line:      start_line
		newline_offsets: newline_offsets
		comments:        comments
		magic_comments:  magic_comments
		data_loc:        data_loc
		errors:          errors
		warnings:        warnings
	}
}

// read_varuint_list reads a length-prefixed list of varuint values.
fn read_varuint_list(mut reader Reader) ![]u32 {
	count := int(reader.read_varuint()!)
	mut values := []u32{cap: count}

	for _ in 0 .. count {
		values << reader.read_varuint()!
	}

	return values
}

// read_comments reads serialized comment metadata.
pub fn read_comments(mut reader Reader) ![]Comment {
	count := int(reader.read_varuint()!)
	mut comments := []Comment{cap: count}

	for _ in 0 .. count {
		raw_kind := reader.read_varuint()!
		kind := match raw_kind {
			0 { CommentKind.inline }
			1 { CommentKind.embdoc }
			else { return error('unknown serialized comment kind: ${raw_kind}') }
		}

		comments << Comment{
			kind:     kind
			location: reader.read_location()!
		}
	}

	return comments
}

// read_magic_comments reads serialized magic comment metadata.
fn read_magic_comments(mut reader Reader) ![]MagicComment {
	count := int(reader.read_varuint()!)
	mut comments := []MagicComment{cap: count}

	for _ in 0 .. count {
		comments << MagicComment{
			key_loc:   reader.read_location()!
			value_loc: reader.read_location()!
		}
	}

	return comments
}

// read_diagnostics reads serialized parser errors or warnings.
fn read_diagnostics(mut reader Reader) ![]Diagnostic {
	count := int(reader.read_varuint()!)
	mut diagnostics := []Diagnostic{cap: count}

	for _ in 0 .. count {
		diagnostics << Diagnostic{
			kind:     diagnostic_kind_from_value(reader.read_varuint()!)!
			message:  reader.read_string()!
			location: reader.read_location()!
			level:    DiagnosticLevel(reader.read_u8()!)
		}
	}

	return diagnostics
}
