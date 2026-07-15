module ast

// NodeBase contains metadata shared by every Prism AST node.
pub struct NodeBase {
pub:
	// kind identifies the concrete Prism AST node type.
	kind NodeKind

	// id is the serialized Prism node id.
	id u32

	// location points into the original Ruby source byte offsets.
	location Location

	// flags stores Prism node flags as a typed bitset.
	flags NodeFlags

	// serialized_length stores Prism's lazy node length when present.
	serialized_length u32
}
