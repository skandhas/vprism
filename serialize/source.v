module serialize

import vprism.ast

// SourcePosition identifies a one-based line and byte column in Ruby source.
pub struct SourcePosition {
pub:
	// line is the one-based source line including the configured start line.
	line i32

	// column is the one-based byte column within the line.
	column u32

	// offset is the zero-based byte offset within the complete source.
	offset u32
}

// SourceRange describes a half-open source range with an exclusive end.
pub struct SourceRange {
pub:
	// start is the inclusive source position.
	start SourcePosition

	// end is the exclusive source position.
	end SourcePosition
}

// position_at converts a source byte offset to a one-based line and byte column.
pub fn (result ParseResult) position_at(offset u32) !SourcePosition {
	if u64(offset) > u64(result.source.len) {
		return error('source offset is outside source')
	}

	line_starts := result.line_starts()
	line_index := line_index_at(line_starts, offset)
	line_start := line_starts[line_index]

	return SourcePosition{
		line:   result.metadata.start_line + i32(line_index)
		column: offset - line_start + 1
		offset: offset
	}
}

// location_range converts a Prism location to a half-open source range.
pub fn (result ParseResult) location_range(location ast.Location) !SourceRange {
	end_offset := u64(location.start_offset) + u64(location.length)

	if end_offset > u64(result.source.len) {
		return error('location is outside source')
	}

	return SourceRange{
		start: result.position_at(location.start_offset)!
		end:   result.position_at(u32(end_offset))!
	}
}

// node_range returns the half-open source range covered by a decoded node.
pub fn (result ParseResult) node_range(node ast.Node) !SourceRange {
	return result.location_range(node.base().location)
}

// line_text returns one source line without its trailing line ending.
pub fn (result ParseResult) line_text(line i32) !string {
	line_starts := result.line_starts()
	line_index := line - result.metadata.start_line

	if line_index < 0 || line_index >= line_starts.len {
		return error('source line is outside source')
	}

	start := int(line_starts[line_index])
	mut end := if line_index + 1 < line_starts.len {
		int(line_starts[line_index + 1])
	} else {
		result.source.len
	}
	bytes := result.source.bytes()

	if end > start && bytes[end - 1] == `\n` {
		end--
	}

	if end > start && bytes[end - 1] == `\r` {
		end--
	}

	return bytes[start..end].bytestr()
}

// line_starts returns normalized source line start offsets.
fn (result ParseResult) line_starts() []u32 {
	if result.metadata.newline_offsets.len == 0 || result.metadata.newline_offsets[0] != 0 {
		return [u32(0)]
	}

	return result.metadata.newline_offsets
}

// line_index_at finds the greatest line start not exceeding offset.
fn line_index_at(line_starts []u32, offset u32) int {
	mut left := 0
	mut right := line_starts.len

	for left + 1 < right {
		middle := left + (right - left) / 2

		if line_starts[middle] <= offset {
			left = middle
		} else {
			right = middle
		}
	}

	return left
}
