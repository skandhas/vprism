module analysis

import vprism.ast

// AnalysisIndex caches structural relationships for one decoded Ruby source.
pub struct AnalysisIndex {
	nodes       map[u32]ast.Node
	parent_ids  map[u32]u32
	scope_paths map[u32][]u32
}

// analysis_index builds a reusable structural index for the decoded AST.
pub fn (result &Analyzer) analysis_index() AnalysisIndex {
	mut nodes := map[u32]ast.Node{}
	mut parent_ids := map[u32]u32{}
	mut scope_paths := map[u32][]u32{}
	mut active_scopes := []u32{}

	index_analysis_node(result.root, none, mut active_scopes, mut nodes, mut parent_ids, mut
		scope_paths)

	return AnalysisIndex{
		nodes:       nodes
		parent_ids:  parent_ids
		scope_paths: scope_paths
	}
}

// node returns the decoded node with id when it belongs to this index.
pub fn (index AnalysisIndex) node(id u32) ?ast.Node {
	return index.nodes[id] or { none }
}

// parent returns the direct parent of node when one exists in this index.
pub fn (index AnalysisIndex) parent(node ast.Node) ?ast.Node {
	if node.base().id !in index.nodes {
		return none
	}

	parent_id := index.parent_ids[node.base().id] or { return none }

	return index.nodes[parent_id] or { none }
}

// ancestors returns node ancestors from the direct parent to the AST root.
pub fn (index AnalysisIndex) ancestors(node ast.Node) []ast.Node {
	mut ancestors := []ast.Node{}
	mut current_id := node.base().id

	for {
		parent_id := index.parent_ids[current_id] or { break }
		parent := index.nodes[parent_id] or { break }
		ancestors << parent
		current_id = parent_id
	}

	return ancestors
}

// scope_nodes returns cached lexical scope nodes from outermost to innermost.
pub fn (index AnalysisIndex) scope_nodes(node ast.Node) ![]ast.Node {
	if node.base().id !in index.nodes {
		return error('node does not belong to this analysis index')
	}

	scope_ids := index.scope_paths[node.base().id] or {
		return error('node does not belong to this analysis index')
	}
	mut scopes := []ast.Node{cap: scope_ids.len}

	for scope_id in scope_ids {
		scope_node := index.nodes[scope_id] or { return error('indexed scope node is missing') }

		scopes << scope_node
	}

	return scopes
}

// index_analysis_node records one node and recursively indexes its descendants.
fn index_analysis_node(node ast.Node, parent_id ?u32, mut active_scopes []u32, mut nodes map[u32]ast.Node, mut parent_ids map[u32]u32, mut scope_paths map[u32][]u32) {
	nodes[node.base().id] = node
	scope_paths[node.base().id] = active_scopes.clone()

	if id := parent_id {
		parent_ids[node.base().id] = id
	}

	is_scope := scope_kind(node.base().kind) != none

	if is_scope {
		active_scopes << node.base().id
	}

	for child in node.child_nodes() {
		index_analysis_node(child, node.base().id, mut active_scopes, mut nodes, mut parent_ids, mut
			scope_paths)
	}

	if is_scope {
		active_scopes.delete_last()
	}
}
