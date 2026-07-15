module serialize

import vprism.ast

const constant_pool_owned_mask = u32(1) << 31

// ConstantPool describes strings referenced by serialized Prism AST nodes.
pub struct ConstantPool {
pub:
	// base is the byte offset where constant pool entries start.
	base u32

	// size is the number of entries in the constant pool.
	size u32

	// entries contains one entry for each serialized constant.
	entries []ConstantPoolEntry
}

// ConstantPoolEntry describes one serialized constant pool entry.
pub struct ConstantPoolEntry {
pub:
	// offset is either a source offset or a serialized-buffer offset.
	offset u32

	// length is the byte length of the constant.
	length u32

	// owned is true when offset points into the serialized buffer.
	owned bool

	// embedded_value stores owned constants copied from the serialized buffer.
	embedded_value string
}

// read_constant_pool reads the constant pool trailer from serialized Prism bytes.
pub fn read_constant_pool(data []u8, base u32, size u32) !ConstantPool {
	base_offset_u64 := u64(base)
	entry_count_u64 := u64(size)
	table_length_u64 := entry_count_u64 * 8

	if base_offset_u64 + table_length_u64 > u64(data.len) {
		return error('constant pool table is outside serialized data')
	}

	base_offset := int(base)
	entry_count := int(size)
	mut entries := []ConstantPoolEntry{cap: entry_count}

	for index in 0 .. entry_count {
		entry_offset := base_offset + index * 8
		raw_offset := read_u32_le_at(data, entry_offset)!
		length := read_u32_le_at(data, entry_offset + 4)!
		owned := raw_offset & constant_pool_owned_mask != 0
		offset := raw_offset & ~constant_pool_owned_mask
		mut embedded_value := ''

		if owned {
			value_offset_u64 := u64(offset)
			value_length_u64 := u64(length)

			if value_offset_u64 + value_length_u64 > u64(data.len) {
				return error('owned constant points outside serialized data')
			}

			value_offset := int(offset)
			value_length := int(length)
			embedded_value = data[value_offset..value_offset + value_length].bytestr()
		}

		entries << ConstantPoolEntry{
			offset:         offset
			length:         length
			owned:          owned
			embedded_value: embedded_value
		}
	}

	return ConstantPool{
		base:    base
		size:    size
		entries: entries
	}
}

// value returns the decoded constant value for a constant id.
pub fn (pool ConstantPool) value(source string, id ast.ConstantId) !string {
	index := int(u32(id))

	if index < 0 || index >= pool.entries.len {
		return error('constant id is outside constant pool')
	}

	entry := pool.entries[index]

	if entry.owned {
		return entry.embedded_value
	}

	start_u64 := u64(entry.offset)
	length_u64 := u64(entry.length)

	if start_u64 + length_u64 > u64(source.len) {
		return error('shared constant points outside source')
	}

	start := int(entry.offset)
	length := int(entry.length)

	return source.bytes()[start..start + length].bytestr()
}

// read_u32_le_at reads a fixed-width little-endian uint32 at an absolute offset.
fn read_u32_le_at(data []u8, offset int) !u32 {
	if offset < 0 || offset + 4 > data.len {
		return error('unexpected end of serialized data')
	}

	return u32(data[offset]) | (u32(data[offset + 1]) << 8) | (u32(data[offset + 2]) << 16) | (u32(data[
		offset + 3]) << 24)
}
