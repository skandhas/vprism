module analysis

import vprism.ast

// scope_info builds a lexical scope description from a scope node.
fn (result Analyzer) scope_info(node ast.Node) !ScopeInfo {
	kind := scope_kind(node.base().kind) or { return error('node is not a lexical scope') }
	mut name := ''
	mut constant_path := ''

	match node.base().kind {
		.class {
			class_node := node.as_class()!
			name = result.constant_value(class_node.name)!
			constant_path = result.node_text(class_node.constant_path) or { name }
		}
		.module_ {
			module_node := node.as_module_()!
			name = result.constant_value(module_node.name)!
			constant_path = result.node_text(module_node.constant_path) or { name }
		}
		.singleton_class {
			singleton_node := node.as_singleton_class()!
			name = result.node_text(singleton_node.expression) or { '' }
		}
		.def {
			def_node := node.as_def()!
			name = result.constant_value(def_node.name)!
		}
		else {}
	}

	text := result.node_text(node) or { '' }

	return ScopeInfo{
		kind:          kind
		name:          name
		constant_path: constant_path
		text:          text
		node:          node
	}
}

// scope_methods returns method definitions belonging directly to a class or module scope.
fn (result Analyzer) scope_methods(scope_node ast.Node) []MethodInfo {
	body := result.scope_body(scope_node) or { return []MethodInfo{} }
	mut nodes := []ast.Node{}

	collect_direct_scope_nodes(body, .def, mut nodes)
	nodes.sort(a.base().location.start_offset < b.base().location.start_offset)
	visibilities := result.scope_method_visibilities(body, nodes)

	mut methods := []MethodInfo{cap: nodes.len}

	for node in nodes {
		visibility := visibilities[node.base().id] or { MethodVisibility.public_ }

		methods << result.method_info(node, visibility) or { continue }
	}

	return methods
}

// method_calls returns calls from a method body without crossing nested scope boundaries.
fn (result Analyzer) method_calls(method_node ast.Node) []CallInfo {
	method := method_node.as_def() or { return []CallInfo{} }
	body := method.body or { return []CallInfo{} }
	mut nodes := []ast.Node{}

	collect_direct_scope_nodes(body, .call, mut nodes)
	sort_nodes_by_source(mut nodes)

	mut calls := []CallInfo{cap: nodes.len}

	for node in nodes {
		calls << result.call_info(node) or { continue }
	}

	return calls
}

// scope_method_visibilities resolves visibility declarations for direct methods.
fn (result Analyzer) scope_method_visibilities(body ast.Node, methods []ast.Node) map[u32]MethodVisibility {
	mut calls := []ast.Node{}

	collect_direct_scope_nodes(body, .call, mut calls)
	calls.sort(a.base().location.start_offset < b.base().location.start_offset)

	mut visibilities := map[u32]MethodVisibility{}
	mut current := MethodVisibility.public_
	mut call_index := 0

	for method in methods {
		for call_index < calls.len
			&& calls[call_index].base().location.start_offset < method.base().location.start_offset {
			call := calls[call_index]

			if visibility := result.visibility_call(call) {
				if !result.call_has_arguments(call) {
					current = visibility
				}
			}

			call_index++
		}

		method_ast := method.as_def() or { continue }
		visibilities[method.base().id] = if method_ast.receiver != none {
			MethodVisibility.public_
		} else {
			current
		}
	}

	for call in calls {
		visibility := result.visibility_call(call) or { continue }

		for method in methods {
			method_ast := method.as_def() or { continue }

			if method_ast.receiver != none {
				continue
			}

			if result.visibility_call_targets_method(call, method) {
				visibilities[method.base().id] = visibility
			}
		}
	}

	return visibilities
}

// visibility_call maps a receiverless visibility call to its visibility value.
fn (result Analyzer) visibility_call(call ast.Node) ?MethodVisibility {
	call_ast := call.as_call() or { return none }

	if call_ast.receiver != none {
		return none
	}

	name := result.constant_value(call_ast.name) or { return none }

	return match name {
		'public' { MethodVisibility.public_ }
		'protected' { MethodVisibility.protected_ }
		'private' { MethodVisibility.private_ }
		else { none }
	}
}

// call_has_arguments reports whether a CallNode has an ArgumentsNode.
fn (result Analyzer) call_has_arguments(call ast.Node) bool {
	call_ast := call.as_call() or { return false }

	return call_ast.arguments != none
}

// visibility_call_targets_method checks explicit visibility declarations for a method.
fn (result Analyzer) visibility_call_targets_method(call ast.Node, method ast.Node) bool {
	for target in call.find_all(.def) {
		if target.base().id == method.base().id {
			return true
		}
	}

	method_ast := method.as_def() or { return false }
	method_name := result.constant_value(method_ast.name) or { return false }

	return method_name in result.visibility_call_names(call)
}

// visibility_call_names returns symbol names passed to a visibility call.
fn (result Analyzer) visibility_call_names(call ast.Node) []string {
	call_ast := call.as_call() or { return []string{} }
	arguments := call_ast.arguments or { return []string{} }
	arguments_ast := arguments.as_arguments() or { return []string{} }
	mut names := []string{}

	for node in arguments_ast.arguments {
		if node.base().kind != .symbol {
			continue
		}

		symbol_node := node.as_symbol() or { continue }

		names << symbol_node.unescaped
	}

	return names
}

// scope_nested_definitions returns direct class and module definitions in a scope.
fn (result Analyzer) scope_nested_definitions(scope_node ast.Node) []DefinitionInfo {
	body := result.scope_body(scope_node) or { return []DefinitionInfo{} }
	mut nodes := []ast.Node{}

	collect_direct_scope_nodes(body, .class, mut nodes)
	collect_direct_scope_nodes(body, .module_, mut nodes)
	nodes.sort(a.base().location.start_offset < b.base().location.start_offset)

	mut definitions := []DefinitionInfo{cap: nodes.len}

	for node in nodes {
		definitions << result.definition_info(node) or { continue }
	}

	return definitions
}

// scope_body returns the body node of a class or module when present.
fn (result Analyzer) scope_body(scope_node ast.Node) ?ast.Node {
	match scope_node.base().kind {
		.class { return scope_node.as_class() or { return none }.body }
		.module_ { return scope_node.as_module_() or { return none }.body }
		.singleton_class { return scope_node.as_singleton_class() or { return none }.body }
		else { return none }
	}
}

// definition_info builds a lightweight description of a class or module node.
fn (result Analyzer) definition_info(node ast.Node) !DefinitionInfo {
	name, constant_path := if node.base().kind == .class {
		class_node := node.as_class()!
		result.constant_value(class_node.name)!, result.node_text(class_node.constant_path)!
	} else {
		module_node := node.as_module_()!
		result.constant_value(module_node.name)!, result.node_text(module_node.constant_path)!
	}
	text := result.node_text(node) or { '' }
	kind := if node.base().kind == .class {
		DefinitionKind.class_definition
	} else {
		DefinitionKind.module_definition
	}

	return DefinitionInfo{
		kind:          kind
		name:          name
		constant_path: constant_path
		text:          text
		node:          node
	}
}

// collect_direct_scope_nodes finds target nodes without crossing nested scope boundaries.
fn collect_direct_scope_nodes(node ast.Node, target ast.NodeKind, mut nodes []ast.Node) {
	for child in node.child_nodes() {
		if child.base().kind == target {
			nodes << child
		}

		if child.base().kind in [.class, .module_, .singleton_class, .def] {
			continue
		}

		collect_direct_scope_nodes(child, target, mut nodes)
	}
}

// scope_kind maps a Prism node kind to a lexical scope kind.
fn scope_kind(kind ast.NodeKind) ?ScopeKind {
	return match kind {
		.class { ScopeKind.class_ }
		.module_ { ScopeKind.module_ }
		.singleton_class { ScopeKind.singleton_class }
		.def { ScopeKind.method }
		else { none }
	}
}

// sort_nodes_by_source orders nodes by start offset and then by shorter source length.
fn sort_nodes_by_source(mut nodes []ast.Node) {
	for i in 1 .. nodes.len {
		mut index := i

		for index > 0 {
			previous := nodes[index - 1].base().location
			current := nodes[index].base().location

			if previous.start_offset < current.start_offset
				|| (previous.start_offset == current.start_offset
				&& previous.length <= current.length) {
				break
			}

			nodes[index - 1], nodes[index] = nodes[index], nodes[index - 1]
			index--
		}
	}
}
