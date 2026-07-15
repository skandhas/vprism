module analysis

import vprism.ast

// alias_info builds a high-level description of an alias node.
fn (result Analyzer) alias_info(node ast.Node, kind AliasKind) !AliasInfo {
	new_node, old_node := match kind {
		.method {
			alias_node := node.as_alias_method()!
			alias_node.new_name, alias_node.old_name
		}
		.global_variable {
			alias_node := node.as_alias_global_variable()!
			alias_node.new_name, alias_node.old_name
		}
	}
	new_name := result.name_info(new_node)
	old_name := result.name_info(old_node)
	text := result.node_text(node) or { '' }

	return AliasInfo{
		kind:     kind
		new_name: new_name
		old_name: old_name
		dynamic:  new_name.dynamic || old_name.dynamic
		text:     text
		node:     node
	}
}

// undef_info builds a high-level description of an undef node.
fn (result Analyzer) undef_info(node ast.Node) !UndefInfo {
	undef_node := node.as_undef()!
	name_nodes := undef_node.names
	mut names := []NameInfo{cap: name_nodes.len}

	for name_node in name_nodes {
		names << result.name_info(name_node)
	}

	text := result.node_text(node) or { '' }

	return UndefInfo{
		names: names
		text:  text
		node:  node
	}
}

// name_info builds a static or dynamic name description.
fn (result Analyzer) name_info(node ast.Node) NameInfo {
	name := result.static_name(node) or { '' }
	text := result.node_text(node) or { '' }

	return NameInfo{
		name:    name
		dynamic: name.len == 0
		text:    text
		node:    node
	}
}

// static_name resolves names represented by symbols or global variable nodes.
fn (result Analyzer) static_name(node ast.Node) ?string {
	if node.base().kind == .symbol {
		symbol_node := node.as_symbol() or { return none }

		return symbol_node.unescaped
	}

	if kind := variable_kind(node.base().kind) {
		if kind == .global {
			return result.variable_name(node) or { return none }
		}
	}

	return none
}

// sort_aliases_by_source orders aliases by source offset.
fn sort_aliases_by_source(mut aliases []AliasInfo) {
	aliases.sort(a.node.base().location.start_offset < b.node.base().location.start_offset)
}
