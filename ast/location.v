module ast

// Location describes a byte range in the original Ruby source.
pub struct Location {
pub:
	// start_offset is the byte offset from the start of the source.
	start_offset u32

	// length is the byte length of the source range.
	length u32
}
