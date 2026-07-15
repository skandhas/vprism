module analysis

// dependency_info builds dependency information for a supported loading call.
fn (result Analyzer) dependency_info(call CallInfo) ?DependencyInfo {
	kind := dependency_kind(call.name) or { return none }

	if receiver := call.receiver {
		if receiver.text != 'Kernel' {
			return none
		}
	}

	path_index := if kind == .autoload { 1 } else { 0 }
	path := result.call_string_argument(call, path_index) or { '' }
	constant_name := if kind == .autoload {
		result.call_symbol_argument(call, 0) or { '' }
	} else {
		''
	}

	return DependencyInfo{
		kind:          kind
		path:          path
		constant_name: constant_name
		dynamic:       path.len == 0
		call:          call
	}
}

// call_string_argument returns an unescaped plain string argument by index.
fn (result Analyzer) call_string_argument(call CallInfo, index int) ?string {
	if index < 0 || index >= call.arguments.len {
		return none
	}

	node := call.arguments[index].node

	if node.base().kind != .string {
		return none
	}

	string_node := node.as_string() or { return none }

	return string_node.unescaped
}

// call_symbol_argument returns an unescaped plain symbol argument by index.
fn (result Analyzer) call_symbol_argument(call CallInfo, index int) ?string {
	if index < 0 || index >= call.arguments.len {
		return none
	}

	node := call.arguments[index].node

	if node.base().kind != .symbol {
		return none
	}

	symbol_node := node.as_symbol() or { return none }

	return symbol_node.unescaped
}

// dependency_kind maps a Ruby loading method name to its dependency kind.
fn dependency_kind(name string) ?DependencyKind {
	return match name {
		'require' { DependencyKind.require_ }
		'require_relative' { DependencyKind.require_relative }
		'load' { DependencyKind.load }
		'autoload' { DependencyKind.autoload }
		else { none }
	}
}
