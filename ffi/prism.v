module ffi

#flag -I@VMODROOT/ffi
#flag -I@VMODROOT/thirdparty/prism/include
#flag @VMODROOT/ffi/prism_shim.c
#flag @VMODROOT/thirdparty/prism/src/diagnostic.c
#flag @VMODROOT/thirdparty/prism/src/encoding.c
#flag @VMODROOT/thirdparty/prism/src/node.c
#flag @VMODROOT/thirdparty/prism/src/options.c
#flag @VMODROOT/thirdparty/prism/src/pack.c
#flag @VMODROOT/thirdparty/prism/src/prettyprint.c
#flag @VMODROOT/thirdparty/prism/src/prism.c
#flag @VMODROOT/thirdparty/prism/src/regexp.c
#flag @VMODROOT/thirdparty/prism/src/serialize.c
#flag @VMODROOT/thirdparty/prism/src/static_literals.c
#flag @VMODROOT/thirdparty/prism/src/token_type.c
#flag @VMODROOT/thirdparty/prism/src/util/pm_buffer.c
#flag @VMODROOT/thirdparty/prism/src/util/pm_char.c
#flag @VMODROOT/thirdparty/prism/src/util/pm_constant_pool.c
#flag @VMODROOT/thirdparty/prism/src/util/pm_integer.c
#flag @VMODROOT/thirdparty/prism/src/util/pm_list.c
#flag @VMODROOT/thirdparty/prism/src/util/pm_memchr.c
#flag @VMODROOT/thirdparty/prism/src/util/pm_newline_list.c
#flag @VMODROOT/thirdparty/prism/src/util/pm_string.c
#flag @VMODROOT/thirdparty/prism/src/util/pm_strncasecmp.c
#flag @VMODROOT/thirdparty/prism/src/util/pm_strpbrk.c
#include "prism_shim.h"

// SerializedBuffer mirrors the small C wrapper result for serialized Prism bytes.
@[typedef]
struct C.vprism_serialized_buffer_t {
	data voidptr
	len  usize
}

fn C.vprism_serialize_parse(source &char, source_len usize, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_serialize_parse_with_options(source &char, source_len usize, options &char, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_serialize_parse_stream_file(path &char, options &char, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_serialize_parse_comments(source &char, source_len usize, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_serialize_parse_comments_with_options(source &char, source_len usize, options &char, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_serialize_lex(source &char, source_len usize, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_serialize_lex_with_options(source &char, source_len usize, options &char, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_serialize_parse_lex(source &char, source_len usize, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_serialize_parse_lex_with_options(source &char, source_len usize, options &char, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_parse_success(source &char, source_len usize, out_success &bool) bool
fn C.vprism_parse_success_with_options(source &char, source_len usize, options &char, out_success &bool) bool
fn C.vprism_dump_json(source &char, source_len usize, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_dump_json_with_options(source &char, source_len usize, options &char, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_prettyprint(source &char, source_len usize, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_prettyprint_with_options(source &char, source_len usize, options &char, out &C.vprism_serialized_buffer_t) bool
fn C.vprism_string_query_local(source &char, source_len usize, encoding_name &char) int
fn C.vprism_string_query_constant(source &char, source_len usize, encoding_name &char) int
fn C.vprism_string_query_method_name(source &char, source_len usize, encoding_name &char) int
fn C.vprism_token_type_name(token_type int) &char
fn C.vprism_version() &char
fn C.vprism_last_error() &char
fn C.vprism_serialized_buffer_free(buffer &C.vprism_serialized_buffer_t)

// native_error returns the last C shim error with operation context.
fn native_error(operation string) IError {
	message := unsafe { cstring_to_vstring(C.vprism_last_error()) }

	if message.len > 0 {
		return error('${operation}: ${message}')
	}

	return error('${operation}: unknown Prism native failure')
}

// query_result converts Prism string query results to V bools.
fn query_result(operation string, value string, encoding string, result int) !bool {
	match result {
		-1 {
			return error('${operation}: invalid Ruby source encoding "${encoding}" for "${value}"')
		}
		0 {
			return false
		}
		1 {
			return true
		}
		else {
			return error('${operation}: unexpected Prism string query result ${result}')
		}
	}
}

// serialize_parse calls Prism's pm_serialize_parse and returns serialized AST bytes.
pub fn serialize_parse(source string) ![]u8 {
	mut buffer := C.vprism_serialized_buffer_t{}

	if !C.vprism_serialize_parse(&char(source.str), usize(source.len), &buffer) {
		return native_error('Prism parse serialization failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone() }
}

// serialize_parse_stream_file calls Prism's stream serializer for a Ruby source file.
pub fn serialize_parse_stream_file(path string, options []u8) ![]u8 {
	mut buffer := C.vprism_serialized_buffer_t{}
	options_ptr := if options.len == 0 { &char(unsafe { nil }) } else { &char(options.data) }

	if !C.vprism_serialize_parse_stream_file(&char(path.str), options_ptr, &buffer) {
		return native_error('Prism stream parse serialization failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone() }
}

// parse_success calls Prism's pm_parse_success_p and returns whether the source is valid Ruby.
pub fn parse_success(source string) !bool {
	mut success := false

	if !C.vprism_parse_success(&char(source.str), usize(source.len), &success) {
		return native_error('Prism syntax check failed')
	}

	return success
}

// parse_success_with_options calls Prism's syntax check with serialized parser options.
pub fn parse_success_with_options(source string, options []u8) !bool {
	if options.len == 0 {
		return parse_success(source)
	}

	mut success := false

	if !C.vprism_parse_success_with_options(&char(source.str), usize(source.len),
		&char(options.data), &success) {
		return native_error('Prism syntax check failed')
	}

	return success
}

// prism_version returns the version reported by the bundled Prism C library.
pub fn prism_version() string {
	return unsafe { cstring_to_vstring(C.vprism_version()) }
}

// dump_json calls Prism's JSON dumper and returns the generated JSON text.
pub fn dump_json(source string) !string {
	mut buffer := C.vprism_serialized_buffer_t{}

	if !C.vprism_dump_json(&char(source.str), usize(source.len), &buffer) {
		return native_error('Prism JSON dump failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone().bytestr() }
}

// dump_json_with_options calls Prism's JSON dumper with parser options.
pub fn dump_json_with_options(source string, options []u8) !string {
	if options.len == 0 {
		return dump_json(source)
	}

	mut buffer := C.vprism_serialized_buffer_t{}

	if !C.vprism_dump_json_with_options(&char(source.str), usize(source.len), &char(options.data),
		&buffer) {
		return native_error('Prism JSON dump failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone().bytestr() }
}

// prettyprint calls Prism's AST pretty-printer and returns the generated text.
pub fn prettyprint(source string) !string {
	mut buffer := C.vprism_serialized_buffer_t{}

	if !C.vprism_prettyprint(&char(source.str), usize(source.len), &buffer) {
		return native_error('Prism prettyprint failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone().bytestr() }
}

// prettyprint_with_options calls Prism's AST pretty-printer with parser options.
pub fn prettyprint_with_options(source string, options []u8) !string {
	if options.len == 0 {
		return prettyprint(source)
	}

	mut buffer := C.vprism_serialized_buffer_t{}

	if !C.vprism_prettyprint_with_options(&char(source.str), usize(source.len),
		&char(options.data), &buffer) {
		return native_error('Prism prettyprint failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone().bytestr() }
}

// string_query_local checks whether value is a valid Ruby local variable name.
pub fn string_query_local(value string, encoding string) !bool {
	result := C.vprism_string_query_local(&char(value.str), usize(value.len), &char(encoding.str))

	return query_result('Prism local name query failed', value, encoding, result)
}

// string_query_constant checks whether value is a valid Ruby constant name.
pub fn string_query_constant(value string, encoding string) !bool {
	result := C.vprism_string_query_constant(&char(value.str), usize(value.len),
		&char(encoding.str))

	return query_result('Prism constant name query failed', value, encoding, result)
}

// string_query_method_name checks whether value is a valid Ruby method name.
pub fn string_query_method_name(value string, encoding string) !bool {
	result := C.vprism_string_query_method_name(&char(value.str), usize(value.len),
		&char(encoding.str))

	return query_result('Prism method name query failed', value, encoding, result)
}

// token_type_name returns Prism's official token type name for a token value.
pub fn token_type_name(value int) string {
	return unsafe { cstring_to_vstring(C.vprism_token_type_name(value)) }
}

// serialize_parse_with_options calls Prism with serialized parser options.
pub fn serialize_parse_with_options(source string, options []u8) ![]u8 {
	if options.len == 0 {
		return serialize_parse(source)
	}

	mut buffer := C.vprism_serialized_buffer_t{}

	if !C.vprism_serialize_parse_with_options(&char(source.str), usize(source.len),
		&char(options.data), &buffer) {
		return native_error('Prism parse serialization failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone() }
}

// serialize_parse_comments calls Prism's pm_serialize_parse_comments and returns serialized comment bytes.
pub fn serialize_parse_comments(source string) ![]u8 {
	mut buffer := C.vprism_serialized_buffer_t{}

	if !C.vprism_serialize_parse_comments(&char(source.str), usize(source.len), &buffer) {
		return native_error('Prism comments serialization failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone() }
}

// serialize_parse_comments_with_options calls Prism's comments serializer with parser options.
pub fn serialize_parse_comments_with_options(source string, options []u8) ![]u8 {
	if options.len == 0 {
		return serialize_parse_comments(source)
	}

	mut buffer := C.vprism_serialized_buffer_t{}

	if !C.vprism_serialize_parse_comments_with_options(&char(source.str), usize(source.len),
		&char(options.data), &buffer) {
		return native_error('Prism comments serialization failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone() }
}

// serialize_lex calls Prism's pm_serialize_lex and returns serialized token bytes.
pub fn serialize_lex(source string) ![]u8 {
	mut buffer := C.vprism_serialized_buffer_t{}

	if !C.vprism_serialize_lex(&char(source.str), usize(source.len), &buffer) {
		return native_error('Prism lex serialization failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone() }
}

// serialize_lex_with_options calls Prism's lexer with serialized parser options.
pub fn serialize_lex_with_options(source string, options []u8) ![]u8 {
	if options.len == 0 {
		return serialize_lex(source)
	}

	mut buffer := C.vprism_serialized_buffer_t{}

	if !C.vprism_serialize_lex_with_options(&char(source.str), usize(source.len),
		&char(options.data), &buffer) {
		return native_error('Prism lex serialization failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone() }
}

// serialize_parse_lex calls Prism's pm_serialize_parse_lex and returns tokens followed by serialized AST bytes.
pub fn serialize_parse_lex(source string) ![]u8 {
	mut buffer := C.vprism_serialized_buffer_t{}

	if !C.vprism_serialize_parse_lex(&char(source.str), usize(source.len), &buffer) {
		return native_error('Prism parse-lex serialization failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone() }
}

// serialize_parse_lex_with_options calls Prism's parse+lex serializer with parser options.
pub fn serialize_parse_lex_with_options(source string, options []u8) ![]u8 {
	if options.len == 0 {
		return serialize_parse_lex(source)
	}

	mut buffer := C.vprism_serialized_buffer_t{}

	if !C.vprism_serialize_parse_lex_with_options(&char(source.str), usize(source.len),
		&char(options.data), &buffer) {
		return native_error('Prism parse-lex serialization failed')
	}

	defer {
		C.vprism_serialized_buffer_free(&buffer)
	}

	return unsafe { (&u8(buffer.data)).vbytes(int(buffer.len)).clone() }
}
