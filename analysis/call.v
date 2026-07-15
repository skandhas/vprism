module analysis

import vprism.ast

// call_receiver returns the explicit receiver of a call when present.
fn (result Analyzer) call_receiver(call_node ast.Node) ?CallReceiverInfo {
	call := call_node.as_call() or { return none }
	receiver_node := call.receiver or { return none }

	return CallReceiverInfo{
		text: result.node_text(receiver_node) or { '' }
		node: receiver_node
	}
}

// call_arguments returns arguments from a call's ArgumentsNode in source order.
fn (result Analyzer) call_arguments(call_node ast.Node) []CallArgumentInfo {
	call := call_node.as_call() or { return []CallArgumentInfo{} }
	arguments_node := call.arguments or { return []CallArgumentInfo{} }
	arguments_ast := arguments_node.as_arguments() or { return []CallArgumentInfo{} }
	argument_nodes := arguments_ast.arguments
	mut arguments := []CallArgumentInfo{cap: argument_nodes.len}

	for argument_node in argument_nodes {
		text := result.node_text(argument_node) or { '' }

		arguments << CallArgumentInfo{
			text: text
			kind: call_argument_kind(argument_node.base().kind)
			node: argument_node
		}
	}

	return arguments
}

// call_block returns the block attached to a call when present.
fn (result Analyzer) call_block(call_node ast.Node) ?CallBlockInfo {
	call := call_node.as_call() or { return none }
	block_node := call.block or { return none }

	return CallBlockInfo{
		text: result.node_text(block_node) or { '' }
		kind: call_block_kind(block_node.base().kind)
		node: block_node
	}
}

// call_argument_kind maps a Prism argument node kind to the analysis enum.
fn call_argument_kind(kind ast.NodeKind) CallArgumentKind {
	return match kind {
		.splat {
			.splat
		}
		.keyword_hash {
			.keywords
		}
		.forwarding_arguments {
			.forwarding
		}
		else {
			.positional
		}
	}
}

// call_block_kind maps a Prism block node kind to the analysis enum.
fn call_block_kind(kind ast.NodeKind) CallBlockKind {
	return match kind {
		.block {
			.literal
		}
		.block_argument {
			.argument
		}
		else {
			.unknown
		}
	}
}

// method_parameters returns the parameter list for a method definition node.
fn (result Analyzer) method_parameters(method_node ast.Node) []ParameterInfo {
	method := method_node.as_def() or { return []ParameterInfo{} }
	parameters_node := method.parameters or { return []ParameterInfo{} }

	return result.parameters_from_node(parameters_node)
}

// parameters_from_node returns parameter infos from a Prism ParametersNode.
fn (result Analyzer) parameters_from_node(parameters_node ast.Node) []ParameterInfo {
	parameters_ast := parameters_node.as_parameters() or { return []ParameterInfo{} }
	mut parameters := []ParameterInfo{}

	for node in parameters_ast.requireds {
		result.append_parameter(node, mut parameters)
	}

	for node in parameters_ast.optionals {
		result.append_parameter(node, mut parameters)
	}

	if node := parameters_ast.rest {
		result.append_parameter(node, mut parameters)
	}
	for node in parameters_ast.posts {
		result.append_parameter(node, mut parameters)
	}

	for node in parameters_ast.keywords {
		result.append_parameter(node, mut parameters)
	}

	if node := parameters_ast.keyword_rest {
		result.append_parameter(node, mut parameters)
	}

	if node := parameters_ast.block {
		result.append_parameter(node, mut parameters)
	}
	return parameters
}

// append_parameter appends one decoded parameter when it can be described.
fn (result Analyzer) append_parameter(node ast.Node, mut parameters []ParameterInfo) {
	parameter := result.parameter_info(node) or { return }

	parameters << parameter
}

// parameter_info builds the high-level parameter description for one node.
fn (result Analyzer) parameter_info(node ast.Node) !ParameterInfo {
	name := result.parameter_name(node) or { '' }
	text := result.node_text(node) or { '' }
	kind := parameter_kind(node.base().kind)

	return ParameterInfo{
		name: name
		text: text
		kind: kind
		node: node
	}
}

// parameter_name resolves a parameter name when the node has one.
fn (result Analyzer) parameter_name(node ast.Node) !string {
	id := match node.base().kind {
		.required_parameter {
			node.as_required_parameter()!.name
		}
		.optional_parameter {
			node.as_optional_parameter()!.name
		}
		.required_keyword_parameter {
			node.as_required_keyword_parameter()!.name
		}
		.optional_keyword_parameter {
			node.as_optional_keyword_parameter()!.name
		}
		.rest_parameter {
			node.as_rest_parameter()!.name or { return '' }
		}
		.keyword_rest_parameter {
			node.as_keyword_rest_parameter()!.name or { return '' }
		}
		.block_parameter {
			node.as_block_parameter()!.name or { return '' }
		}
		else {
			return ''
		}
	}

	return result.constant_value(id)
}

// parameter_kind maps a Prism parameter node kind to the analysis enum.
fn parameter_kind(kind ast.NodeKind) ParameterKind {
	return match kind {
		.required_parameter {
			.required
		}
		.optional_parameter {
			.optional
		}
		.rest_parameter {
			.rest
		}
		.required_keyword_parameter {
			.required_keyword
		}
		.optional_keyword_parameter {
			.optional_keyword
		}
		.keyword_rest_parameter {
			.keyword_rest
		}
		.block_parameter {
			.block
		}
		.forwarding_parameter {
			.forwarding
		}
		.no_keywords_parameter {
			.no_keywords
		}
		else {
			.unknown
		}
	}
}
