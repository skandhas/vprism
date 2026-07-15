module serialize

import vprism.ast

// OptionalLocation stores an optional Prism source location.
pub struct OptionalLocation {
pub:
	// has_value is true when value contains a real location.
	has_value bool

	// value contains the decoded location when has_value is true.
	value ast.Location
}

// OptionalConstantId stores an optional Prism constant pool id.
pub struct OptionalConstantId {
pub:
	// has_value is true when value contains a real constant id.
	has_value bool

	// value contains the decoded constant id when has_value is true.
	value ast.ConstantId
}
