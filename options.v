module vprism

// RubyVersion identifies the Ruby syntax version used by Prism.
pub enum RubyVersion {
	latest
	ruby_3_3
	ruby_3_4
	ruby_3_5
	ruby_4_0
	ruby_4_1
}

// ForwardingKind identifies arguments available for forwarding in an outer scope.
pub enum ForwardingKind {
	positional
	keywords
	block
	all
}

// ParseScope describes locals and forwarding available in an outer parser scope.
pub struct ParseScope {
pub:
	// locals contains local variable names available in this scope.
	locals []string

	// forwarding contains argument forwarding forms available in this scope.
	forwarding []ForwardingKind
}

// ParseOptions configures Prism parsing for one Ruby source.
pub struct ParseOptions {
pub:
	// filepath is reported by `__FILE__` and source-file nodes.
	filepath string

	// line is the one-based source line for the first byte.
	line i32 = 1

	// encoding selects the initial source encoding when non-empty.
	encoding string

	// frozen_string_literal enables frozen string literal semantics.
	frozen_string_literal bool

	// command_line contains Ruby command-line flags from `aelnpx`.
	command_line string

	// version selects the Ruby syntax version.
	version RubyVersion

	// encoding_locked prevents magic comments from changing the selected encoding.
	encoding_locked bool

	// main_script enables main-script parsing behavior.
	main_script bool

	// partial_script allows parsing an incomplete script.
	partial_script bool

	// freeze requests frozen Prism parse objects where supported.
	freeze bool

	// scopes contains outer local-variable scopes from outermost to innermost.
	scopes []ParseScope
}

// serialize encodes options using Prism's documented FFI option format.
fn (options ParseOptions) serialize() ![]u8 {
	return options.serialize_with_filepath(options.filepath)
}

// serialize_with_filepath encodes options with an explicit source filepath.
fn (options ParseOptions) serialize_with_filepath(filepath string) ![]u8 {
	if options.line < 1 {
		return error('parse option line must be at least 1')
	}

	command_line := command_line_flags(options.command_line)!
	mut data := []u8{}

	append_string(mut data, filepath)
	append_i32_le(mut data, options.line)
	append_string(mut data, options.encoding)
	data << bool_byte(options.frozen_string_literal)
	data << command_line
	data << ruby_version_byte(options.version)
	data << bool_byte(options.encoding_locked)
	data << bool_byte(options.main_script)
	data << bool_byte(options.partial_script)
	data << bool_byte(options.freeze)
	append_u32_le(mut data, u32(options.scopes.len))

	for scope in options.scopes {
		append_u32_le(mut data, u32(scope.locals.len))
		data << forwarding_flags(scope.forwarding)

		for local in scope.locals {
			append_string(mut data, local)
		}
	}

	return data
}

// command_line_flags encodes supported Ruby command-line parser flags.
fn command_line_flags(flags string) !u8 {
	mut value := u8(0)

	for flag in flags.bytes() {
		match flag {
			`a` { value |= 0x01 }
			`e` { value |= 0x02 }
			`l` { value |= 0x04 }
			`n` { value |= 0x08 }
			`p` { value |= 0x10 }
			`x` { value |= 0x20 }
			else { return error('unsupported command-line parse flag: ${rune(flag)}') }
		}
	}

	return value
}

// ruby_version_byte maps a public Ruby version to Prism's serialized value.
fn ruby_version_byte(version RubyVersion) u8 {
	return match version {
		.latest { 0 }
		.ruby_3_3 { 1 }
		.ruby_3_4 { 2 }
		.ruby_3_5, .ruby_4_0 { 3 }
		.ruby_4_1 { 4 }
	}
}

// forwarding_flags encodes argument forwarding forms as a bitset.
fn forwarding_flags(forwarding []ForwardingKind) u8 {
	mut value := u8(0)

	for kind in forwarding {
		value |= match kind {
			.positional { u8(0x01) }
			.keywords { u8(0x02) }
			.block { u8(0x04) }
			.all { u8(0x08) }
		}
	}

	return value
}

// bool_byte converts a boolean option to Prism's byte representation.
fn bool_byte(value bool) u8 {
	return if value { u8(1) } else { u8(0) }
}

// append_string appends a little-endian length and raw string bytes.
fn append_string(mut data []u8, value string) {
	append_u32_le(mut data, u32(value.len))
	data << value.bytes()
}

// append_i32_le appends a signed 32-bit value in little-endian order.
fn append_i32_le(mut data []u8, value i32) {
	append_u32_le(mut data, u32(value))
}

// append_u32_le appends an unsigned 32-bit value in little-endian order.
fn append_u32_le(mut data []u8, value u32) {
	data << u8(value)
	data << u8(value >> 8)
	data << u8(value >> 16)
	data << u8(value >> 24)
}
