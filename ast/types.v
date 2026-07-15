module ast

// ConstantId is a zero-based index into Prism's serialized constant pool.
pub type ConstantId = u32

// Integer stores a serialized Ruby integer literal as sign and 32-bit limbs.
pub struct Integer {
pub:
	// negative is true when the original Ruby integer is negative.
	negative bool

	// limbs contains little-endian 32-bit integer limbs.
	limbs []u32
}

// UnknownField is a placeholder for Prism field types not mapped yet.
pub type UnknownField = string
