module analysis

import vprism.ast

// method_control_flows returns direct control-flow expressions from a method body.
fn (result Analyzer) method_control_flows(method_node ast.Node) []ControlFlowInfo {
	method := method_node.as_def() or { return []ControlFlowInfo{} }
	body := method.body or { return []ControlFlowInfo{} }
	mut nodes := []ast.Node{}

	collect_control_flow_nodes(body, true, mut nodes)
	sort_nodes_by_source(mut nodes)

	return result.control_flow_infos(nodes)
}

// control_flow_infos builds high-level descriptions for control-flow nodes.
fn (result Analyzer) control_flow_infos(nodes []ast.Node) []ControlFlowInfo {
	mut control_flows := []ControlFlowInfo{cap: nodes.len}

	for node in nodes {
		control_flows << result.control_flow_info(node) or { continue }
	}

	return control_flows
}

// control_flow_info builds a high-level control-flow description.
fn (result Analyzer) control_flow_info(node ast.Node) !ControlFlowInfo {
	kind := control_flow_kind(node.base().kind) or { return error('node is not control flow') }
	arguments := result.control_flow_arguments(node)
	block := result.optional_expression(control_flow_block(node))
	text := result.node_text(node) or { '' }

	return ControlFlowInfo{
		kind:               kind
		arguments:          arguments
		block:              block
		forwards_arguments: kind == .forwarding_super
		text:               text
		node:               node
	}
}

// control_flow_arguments returns explicit arguments from a control-flow node.
fn (result Analyzer) control_flow_arguments(node ast.Node) []ExpressionInfo {
	arguments_node := control_flow_arguments_node(node) or { return []ExpressionInfo{} }
	arguments_ast := arguments_node.as_arguments() or { return []ExpressionInfo{} }

	return result.expressions(arguments_ast.arguments)
}

// control_flow_arguments_node returns the ArgumentsNode attached to control flow.
fn control_flow_arguments_node(node ast.Node) ?ast.Node {
	match node.base().kind {
		.return_ { return node.as_return_() or { return none }.arguments }
		.break { return node.as_break() or { return none }.arguments }
		.next { return node.as_next() or { return none }.arguments }
		.yield { return node.as_yield() or { return none }.arguments }
		.super { return node.as_super() or { return none }.arguments }
		else { return none }
	}
}

// control_flow_block returns the block attached to a super expression.
fn control_flow_block(node ast.Node) ?ast.Node {
	match node.base().kind {
		.super { return node.as_super() or { return none }.block }
		.forwarding_super { return node.as_forwarding_super() or { return none }.block }
		else { return none }
	}
}

// collect_control_flow_nodes finds control-flow nodes with optional nested-scope boundaries.
fn collect_control_flow_nodes(node ast.Node, stop_at_nested_scopes bool, mut nodes []ast.Node) {
	for child in node.child_nodes() {
		if control_flow_kind(child.base().kind) != none {
			nodes << child
		}

		if stop_at_nested_scopes && child.base().kind in [.class, .module_, .singleton_class, .def] {
			continue
		}

		collect_control_flow_nodes(child, stop_at_nested_scopes, mut nodes)
	}
}

// control_flow_kind maps a Prism node kind to the high-level control-flow kind.
fn control_flow_kind(kind ast.NodeKind) ?ControlFlowKind {
	return match kind {
		.return_ { ControlFlowKind.return_ }
		.break { ControlFlowKind.break_ }
		.next { ControlFlowKind.next_ }
		.redo { ControlFlowKind.redo }
		.retry { ControlFlowKind.retry }
		.yield { ControlFlowKind.yield_ }
		.super { ControlFlowKind.super_ }
		.forwarding_super { ControlFlowKind.forwarding_super }
		else { none }
	}
}
