module analysis

import vprism.ast

// has_exception_clause reports whether a BeginNode contains exception-related clauses.
fn has_exception_clause(node ast.Node) bool {
	begin_node := node.as_begin() or { return false }

	return begin_node.rescue_clause != none || begin_node.else_clause != none
		|| begin_node.ensure_clause != none
}

// exception_region_info builds a high-level description of a BeginNode.
fn (result Analyzer) exception_region_info(node ast.Node) !ExceptionRegionInfo {
	begin_node := node.as_begin()!
	body := result.optional_expression(begin_node.statements)
	rescues := result.region_rescues(node)
	else_body := result.else_clause_statements(begin_node.else_clause)
	ensure_body := result.ensure_clause_statements(begin_node.ensure_clause)
	text := result.node_text(node) or { '' }

	return ExceptionRegionInfo{
		body:        body
		rescues:     rescues
		else_body:   else_body
		ensure_body: ensure_body
		text:        text
		node:        node
	}
}

// region_rescues returns a BeginNode's linked rescue clauses in source order.
fn (result Analyzer) region_rescues(node ast.Node) []RescueInfo {
	begin_node := node.as_begin() or { return []RescueInfo{} }
	mut current := begin_node.rescue_clause or { return []RescueInfo{} }
	mut rescues := []RescueInfo{}

	for {
		rescues << result.rescue_info(current, false) or { break }
		rescue_node := current.as_rescue() or { break }
		current = rescue_node.subsequent or { break }
	}

	return rescues
}

// rescue_info builds a high-level description of a rescue node.
fn (result Analyzer) rescue_info(node ast.Node, modifier bool) !RescueInfo {
	mut exceptions := []ExpressionInfo{}
	mut reference := ?ExpressionInfo(none)
	mut body := ?ExpressionInfo(none)
	mut protected_expression := ?ExpressionInfo(none)

	if modifier {
		rescue_modifier := node.as_rescue_modifier()!
		body = result.expression(rescue_modifier.rescue_expression)
		protected_expression = result.expression(rescue_modifier.expression)
	} else {
		rescue_node := node.as_rescue()!
		exceptions = result.expressions(rescue_node.exceptions)
		reference = result.optional_expression(rescue_node.reference)
		body = result.optional_expression(rescue_node.statements)
	}

	text := result.node_text(node) or { '' }

	return RescueInfo{
		exceptions:           exceptions
		reference:            reference
		body:                 body
		protected_expression: protected_expression
		modifier:             modifier
		text:                 text
		node:                 node
	}
}

// else_clause_statements returns statements from an optional else clause.
fn (result Analyzer) else_clause_statements(clause ?ast.Node) ?ExpressionInfo {
	node := clause or { return none }
	else_node := node.as_else_() or { return none }

	return result.optional_expression(else_node.statements)
}

// ensure_clause_statements returns statements from an optional ensure clause.
fn (result Analyzer) ensure_clause_statements(clause ?ast.Node) ?ExpressionInfo {
	node := clause or { return none }
	ensure_node := node.as_ensure() or { return none }

	return result.optional_expression(ensure_node.statements)
}

// sort_rescues_by_source orders rescue facts by source offset.
fn sort_rescues_by_source(mut rescues []RescueInfo) {
	rescues.sort(a.node.base().location.start_offset < b.node.base().location.start_offset)
}
