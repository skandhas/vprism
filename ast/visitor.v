module ast

// Visitor is implemented by types that walk Prism AST nodes.
pub interface Visitor {
mut:
	// visit is called with a borrowed node during traversal.
	visit(node &Node) !
}
