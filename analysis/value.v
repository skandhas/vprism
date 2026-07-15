module analysis

import vprism.ast

// collect_constants appends normalized constants while suppressing path fragments.
fn (result Analyzer) collect_constants(node ast.Node, mut constants []ConstantInfo) {
	if usage := constant_usage(node.base().kind) {
		constants << result.constant_info(node, usage) or { return }

		match node.base().kind {
			.class, .module_ {
				constant_path := declaration_constant_path(node) or { return }

				for child in node.child_nodes() {
					if child.base().id == constant_path.base().id {
						continue
					}

					result.collect_constants(child, mut constants)
				}
			}
			.constant_path, .constant_path_target {
				result.collect_constant_path_dependencies(node, mut constants)
				return
			}
			.constant_path_and_write, .constant_path_operator_write, .constant_path_or_write,
			.constant_path_write {
				target, value := constant_path_write_parts(node) or { return }

				result.collect_constant_path_dependencies(target, mut constants)
				result.collect_constants(value, mut constants)
			}
			else {
				for child in node.child_nodes() {
					result.collect_constants(child, mut constants)
				}
			}
		}

		return
	}

	for child in node.child_nodes() {
		result.collect_constants(child, mut constants)
	}
}

// collect_variables appends variable usages from node and all descendants.
fn (result Analyzer) collect_variables(node ast.Node, mut variables []VariableInfo) {
	if kind := variable_kind(node.base().kind) {
		usage := variable_usage(node.base().kind) or { return }

		variables << result.variable_info(node, kind, usage) or { return }
	}

	for child in node.child_nodes() {
		result.collect_variables(child, mut variables)
	}
}

// variable_info builds a high-level variable description.
fn (result Analyzer) variable_info(node ast.Node, kind VariableKind, usage VariableUsage) !VariableInfo {
	name := result.variable_name(node)!
	depth := if kind == .local {
		result.variable_depth(node)
	} else {
		none
	}
	value := if usage == .write {
		result.optional_expression(node_write_value(node))
	} else {
		none
	}
	text := result.node_text(node) or { '' }

	return VariableInfo{
		name:  name
		kind:  kind
		usage: usage
		depth: depth
		value: value
		text:  text
		node:  node
	}
}

// variable_name resolves regular and special Prism variable node names.
fn (result Analyzer) variable_name(node ast.Node) !string {
	return match node.base().kind {
		.it_local_variable_read {
			'it'
		}
		.numbered_reference_read {
			number := node.as_numbered_reference_read()!.number

			'\$${number}'
		}
		else {
			name_id := node_name_id(node) or { return error('variable node has no name') }
			result.constant_value(name_id)!
		}
	}
}

// variable_depth returns the lexical depth of a local variable node.
fn (result Analyzer) variable_depth(node ast.Node) ?u32 {
	return node_depth(node)
}

// collect_constant_path_dependencies preserves constants inside dynamic path receivers.
fn (result Analyzer) collect_constant_path_dependencies(path_node ast.Node, mut constants []ConstantInfo) {
	parent := constant_path_parent(path_node) or { return }

	if parent.base().kind in [.constant_read, .constant_path] {
		return
	}

	result.collect_constants(parent, mut constants)
}

// constant_info builds a normalized constant description.
fn (result Analyzer) constant_info(node ast.Node, usage ConstantUsage) !ConstantInfo {
	name := result.constant_name(node)!
	path := result.constant_path_text(node)!
	value := if usage == .write {
		result.optional_expression(node_write_value(node))
	} else {
		none
	}
	text := result.node_text(node) or { '' }

	return ConstantInfo{
		name:  name
		path:  path
		usage: usage
		value: value
		text:  text
		node:  node
	}
}

// constant_name returns the terminal name represented by a constant node.
fn (result Analyzer) constant_name(node ast.Node) !string {
	if id := declaration_name_id(node) {
		return result.constant_value(id)
	}

	if target, _ := constant_path_write_parts(node) {
		return result.constant_name(target)
	}

	if id := node_name_id(node) {
		return result.constant_value(id)
	}

	return ''
}

// constant_path_text returns the complete source path represented by a constant node.
fn (result Analyzer) constant_path_text(node ast.Node) !string {
	if constant_path := declaration_constant_path(node) {
		return result.node_text(constant_path)
	}

	if target, _ := constant_path_write_parts(node) {
		return result.node_text(target)
	}

	if node.base().kind in [.constant_path, .constant_path_target] {
		return result.node_text(node)
	}

	return result.constant_name(node)
}

// declaration_name_id returns the name id from a class or module declaration.
fn declaration_name_id(node ast.Node) ?ast.ConstantId {
	return match node {
		ast.ClassNode { node.name }
		ast.ModuleNode { node.name }
		else { none }
	}
}

// declaration_constant_path returns the constant path from a class or module declaration.
fn declaration_constant_path(node ast.Node) ?ast.Node {
	match node {
		ast.ClassNode { return node.constant_path }
		ast.ModuleNode { return node.constant_path }
		else { return none }
	}
}

// constant_path_parent returns the parent of a constant path node.
fn constant_path_parent(node ast.Node) ?ast.Node {
	match node {
		ast.ConstantPathNode { return node.parent }
		ast.ConstantPathTargetNode { return node.parent }
		else { return none }
	}
}

// constant_path_write_parts returns the target and value of a constant path write.
fn constant_path_write_parts(node ast.Node) ?(ast.Node, ast.Node) {
	return match node {
		ast.ConstantPathAndWriteNode { node.target, node.value }
		ast.ConstantPathOperatorWriteNode { node.target, node.value }
		ast.ConstantPathOrWriteNode { node.target, node.value }
		ast.ConstantPathWriteNode { node.target, node.value }
		else { none }
	}
}

// node_name_id returns the constant id used as a node's static name.
fn node_name_id(node ast.Node) ?ast.ConstantId {
	return match node {
		ast.BackReferenceReadNode { node.name }
		ast.ClassVariableAndWriteNode { node.name }
		ast.ClassVariableOperatorWriteNode { node.name }
		ast.ClassVariableOrWriteNode { node.name }
		ast.ClassVariableReadNode { node.name }
		ast.ClassVariableTargetNode { node.name }
		ast.ClassVariableWriteNode { node.name }
		ast.ConstantAndWriteNode { node.name }
		ast.ConstantOperatorWriteNode { node.name }
		ast.ConstantOrWriteNode { node.name }
		ast.ConstantReadNode { node.name }
		ast.ConstantTargetNode { node.name }
		ast.ConstantWriteNode { node.name }
		ast.GlobalVariableAndWriteNode { node.name }
		ast.GlobalVariableOperatorWriteNode { node.name }
		ast.GlobalVariableOrWriteNode { node.name }
		ast.GlobalVariableReadNode { node.name }
		ast.GlobalVariableTargetNode { node.name }
		ast.GlobalVariableWriteNode { node.name }
		ast.InstanceVariableAndWriteNode { node.name }
		ast.InstanceVariableOperatorWriteNode { node.name }
		ast.InstanceVariableOrWriteNode { node.name }
		ast.InstanceVariableReadNode { node.name }
		ast.InstanceVariableTargetNode { node.name }
		ast.InstanceVariableWriteNode { node.name }
		ast.LocalVariableAndWriteNode { node.name }
		ast.LocalVariableOperatorWriteNode { node.name }
		ast.LocalVariableOrWriteNode { node.name }
		ast.LocalVariableReadNode { node.name }
		ast.LocalVariableTargetNode { node.name }
		ast.LocalVariableWriteNode { node.name }
		else { none }
	}
}

// node_depth returns the lexical depth carried by a local variable node.
fn node_depth(node ast.Node) ?u32 {
	return match node {
		ast.LocalVariableAndWriteNode { node.depth }
		ast.LocalVariableOperatorWriteNode { node.depth }
		ast.LocalVariableOrWriteNode { node.depth }
		ast.LocalVariableReadNode { node.depth }
		ast.LocalVariableTargetNode { node.depth }
		ast.LocalVariableWriteNode { node.depth }
		else { none }
	}
}

// node_write_value returns the value assigned by a variable or constant write node.
fn node_write_value(node ast.Node) ?ast.Node {
	match node {
		ast.ClassVariableAndWriteNode { return node.value }
		ast.ClassVariableOperatorWriteNode { return node.value }
		ast.ClassVariableOrWriteNode { return node.value }
		ast.ClassVariableWriteNode { return node.value }
		ast.ConstantAndWriteNode { return node.value }
		ast.ConstantOperatorWriteNode { return node.value }
		ast.ConstantOrWriteNode { return node.value }
		ast.ConstantPathAndWriteNode { return node.value }
		ast.ConstantPathOperatorWriteNode { return node.value }
		ast.ConstantPathOrWriteNode { return node.value }
		ast.ConstantPathWriteNode { return node.value }
		ast.ConstantWriteNode { return node.value }
		ast.GlobalVariableAndWriteNode { return node.value }
		ast.GlobalVariableOperatorWriteNode { return node.value }
		ast.GlobalVariableOrWriteNode { return node.value }
		ast.GlobalVariableWriteNode { return node.value }
		ast.InstanceVariableAndWriteNode { return node.value }
		ast.InstanceVariableOperatorWriteNode { return node.value }
		ast.InstanceVariableOrWriteNode { return node.value }
		ast.InstanceVariableWriteNode { return node.value }
		ast.LocalVariableAndWriteNode { return node.value }
		ast.LocalVariableOperatorWriteNode { return node.value }
		ast.LocalVariableOrWriteNode { return node.value }
		ast.LocalVariableWriteNode { return node.value }
		else { return none }
	}
}

// constant_usage maps Prism constant-related nodes to normalized usage kinds.
fn constant_usage(kind ast.NodeKind) ?ConstantUsage {
	return match kind {
		.class, .module_ {
			ConstantUsage.declaration
		}
		.constant_read, .constant_path {
			ConstantUsage.read
		}
		.constant_and_write, .constant_operator_write, .constant_or_write,
		.constant_path_and_write, .constant_path_operator_write, .constant_path_or_write,
		.constant_path_write, .constant_write {
			ConstantUsage.write
		}
		.constant_path_target, .constant_target {
			ConstantUsage.target
		}
		else {
			none
		}
	}
}

// variable_kind maps Prism variable nodes to their variable namespace.
fn variable_kind(kind ast.NodeKind) ?VariableKind {
	return match kind {
		.local_variable_and_write, .local_variable_operator_write, .local_variable_or_write,
		.local_variable_read, .local_variable_target, .local_variable_write,
		.it_local_variable_read {
			VariableKind.local
		}
		.instance_variable_and_write, .instance_variable_operator_write,
		.instance_variable_or_write, .instance_variable_read, .instance_variable_target,
		.instance_variable_write {
			VariableKind.instance
		}
		.class_variable_and_write, .class_variable_operator_write, .class_variable_or_write,
		.class_variable_read, .class_variable_target, .class_variable_write {
			VariableKind.class_
		}
		.global_variable_and_write, .global_variable_operator_write, .global_variable_or_write,
		.global_variable_read, .global_variable_target, .global_variable_write,
		.back_reference_read, .numbered_reference_read {
			VariableKind.global
		}
		else {
			none
		}
	}
}

// variable_usage maps Prism variable nodes to normalized usage kinds.
fn variable_usage(kind ast.NodeKind) ?VariableUsage {
	return match kind {
		.local_variable_read, .instance_variable_read, .class_variable_read, .global_variable_read,
		.it_local_variable_read, .back_reference_read, .numbered_reference_read {
			VariableUsage.read
		}
		.local_variable_and_write, .local_variable_operator_write, .local_variable_or_write,
		.local_variable_write, .instance_variable_and_write, .instance_variable_operator_write,
		.instance_variable_or_write, .instance_variable_write, .class_variable_and_write,
		.class_variable_operator_write, .class_variable_or_write, .class_variable_write,
		.global_variable_and_write, .global_variable_operator_write, .global_variable_or_write,
		.global_variable_write {
			VariableUsage.write
		}
		.local_variable_target, .instance_variable_target, .class_variable_target,
		.global_variable_target {
			VariableUsage.target
		}
		else {
			none
		}
	}
}
