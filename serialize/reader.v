module serialize

import math.bits
import vprism.ast

// Reader reads primitive values from Prism's serialized byte stream.
pub struct Reader {
pub:
	// data is the serialized Prism byte stream.
	data []u8
mut:
	// offset is the next byte position to read.
	offset int
}

// new creates a reader for Prism serialized bytes.
pub fn Reader.new(data []u8) Reader {
	return Reader{
		data: data.clone()
	}
}

// position returns the current byte offset in the reader.
pub fn (r Reader) position() int {
	return r.offset
}

// remaining returns the number of unread bytes.
pub fn (r Reader) remaining() int {
	return r.data.len - r.offset
}

// read_u8 reads one unsigned byte.
pub fn (mut r Reader) read_u8() !u8 {
	if r.offset >= r.data.len {
		return error('unexpected end of serialized data')
	}

	value := r.data[r.offset]
	r.offset++

	return value
}

// unread_u8 moves the reader back by one byte.
pub fn (mut r Reader) unread_u8() ! {
	if r.offset <= 0 {
		return error('cannot unread before the start of serialized data')
	}

	r.offset--
}

// peek_u8 returns the next byte without advancing the reader.
pub fn (r Reader) peek_u8() !u8 {
	if r.offset >= r.data.len {
		return error('unexpected end of serialized data')
	}

	return r.data[r.offset]
}

// read_bytes reads count raw bytes.
pub fn (mut r Reader) read_bytes(count int) ![]u8 {
	if count < 0 {
		return error('cannot read a negative byte count')
	}

	if r.offset + count > r.data.len {
		return error('unexpected end of serialized data')
	}

	bytes := r.data[r.offset..r.offset + count].clone()
	r.offset += count

	return bytes
}

// read_varuint reads a Prism varuint encoded with unsigned LEB128.
pub fn (mut r Reader) read_varuint() !u32 {
	mut result := u32(0)

	for shift := u32(0); shift <= 28; shift += 7 {
		byte := r.read_u8()!
		result |= u32(byte & 0x7f) << shift

		if byte & 0x80 == 0 {
			return result
		}
	}

	return error('varuint exceeds 5 bytes')
}

// read_varsint reads a Prism varsint encoded with ZigZag over LEB128.
pub fn (mut r Reader) read_varsint() !i32 {
	unsigned := r.read_varuint()!
	value := i32(unsigned >> 1)

	if unsigned & 1 == 1 {
		return -value - 1
	}

	return value
}

// read_string reads a Prism serialized string.
pub fn (mut r Reader) read_string() !string {
	length := int(r.read_varuint()!)
	bytes := r.read_bytes(length)!

	return bytes.bytestr()
}

// read_prism_string reads a Prism string field with source or embedded content.
pub fn (mut r Reader) read_prism_string(source string) !string {
	string_type := r.read_u8()!
	return match string_type {
		1 {
			start := int(r.read_varuint()!)
			length := int(r.read_varuint()!)

			if start + length > source.len {
				return error('source string slice is outside the source bounds')
			}

			source.bytes()[start..start + length].bytestr()
		}
		2 {
			r.read_string()!
		}
		else {
			error('unknown serialized string type: ${string_type}')
		}
	}
}

// read_location reads a Prism source location.
pub fn (mut r Reader) read_location() !ast.Location {
	start_offset := r.read_varuint()!
	length := r.read_varuint()!

	return ast.Location{
		start_offset: start_offset
		length:       length
	}
}

// read_optional_location reads a Prism optional source location.
pub fn (mut r Reader) read_optional_location() !OptionalLocation {
	if r.read_u8()! == 0 {
		return OptionalLocation{}
	}

	return OptionalLocation{
		has_value: true
		value:     r.read_location()!
	}
}

// read_constant_id reads a Prism constant pool id as a zero-based index.
pub fn (mut r Reader) read_constant_id() !ast.ConstantId {
	raw_index := r.read_varuint()!

	if raw_index == 0 {
		return error('constant id must be non-zero')
	}

	return ast.ConstantId(raw_index - 1)
}

// read_optional_constant_id reads an optional Prism constant pool id.
pub fn (mut r Reader) read_optional_constant_id() !OptionalConstantId {
	raw_index := r.read_varuint()!

	if raw_index == 0 {
		return OptionalConstantId{}
	}

	return OptionalConstantId{
		has_value: true
		value:     ast.ConstantId(raw_index - 1)
	}
}

// read_optional_node_prefix returns false for nil or rewinds before a present node.
pub fn (mut r Reader) read_optional_node_prefix() !bool {
	if r.read_u8()! == 0 {
		return false
	}

	r.unread_u8()!

	return true
}

// read_u32_le reads a fixed-width little-endian uint32.
pub fn (mut r Reader) read_u32_le() !u32 {
	bytes := r.read_bytes(4)!

	return u32(bytes[0]) | (u32(bytes[1]) << 8) | (u32(bytes[2]) << 16) | (u32(bytes[3]) << 24)
}

// read_uint32_field reads a Prism uint32 node field encoded as a varuint.
pub fn (mut r Reader) read_uint32_field() !u32 {
	return r.read_varuint()
}

// read_integer reads a Prism serialized integer field.
pub fn (mut r Reader) read_integer() !ast.Integer {
	negative := r.read_u8()! != 0
	limb_count := int(r.read_varuint()!)
	mut limbs := []u32{cap: limb_count}

	for _ in 0 .. limb_count {
		limbs << r.read_varuint()!
	}

	return ast.Integer{
		negative: negative
		limbs:    limbs
	}
}

// read_double reads a Prism serialized double field.
pub fn (mut r Reader) read_double() !f64 {
	bytes := r.read_bytes(8)!
	raw := u64(bytes[0]) | (u64(bytes[1]) << 8) | (u64(bytes[2]) << 16) | (u64(bytes[3]) << 24) | (u64(bytes[4]) << 32) | (u64(bytes[5]) << 40) | (u64(bytes[6]) << 48) | (u64(bytes[7]) << 56)

	return bits.f64_from_bits(raw)
}
