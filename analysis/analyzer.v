module analysis

import vprism.ast
import vprism.serialize

// Analyzer provides high-level structural analysis for one decoded Ruby source.
pub struct Analyzer {
	// ParseResult contains the AST, source, diagnostics, and parser metadata.
	serialize.ParseResult
}

// new creates an analyzer for a decoded Ruby source.
pub fn Analyzer.new(result serialize.ParseResult) Analyzer {
	return Analyzer{
		ParseResult: result
	}
}

// CallArgumentKind identifies the Ruby call argument form.
pub enum CallArgumentKind {
	positional
	splat
	keywords
	forwarding
	unknown
}

// CallReceiverInfo describes the receiver of a Ruby method call.
pub struct CallReceiverInfo {
pub:
	// text is the source text covered by the receiver node.
	text string

	// node is the strongly typed Prism receiver node.
	node ast.Node
}

// CallArgumentInfo describes an argument passed to a Ruby method call.
pub struct CallArgumentInfo {
pub:
	// text is the source text covered by the argument node.
	text string

	// kind identifies the Ruby call argument form.
	kind CallArgumentKind

	// node is the strongly typed Prism argument node.
	node ast.Node
}

// CallBlockKind identifies how a block is passed to a Ruby method call.
pub enum CallBlockKind {
	literal
	argument
	unknown
}

// CallBlockInfo describes a block passed to a Ruby method call.
pub struct CallBlockInfo {
pub:
	// text is the source text covered by the block node.
	text string

	// kind identifies whether the block is literal or passed with `&`.
	kind CallBlockKind

	// node is the strongly typed Prism block node.
	node ast.Node
}

// CallInfo describes a Ruby method call found in a parsed source.
pub struct CallInfo {
pub:
	// name is the method name referenced by the call.
	name string

	// receiver describes the explicit call receiver when present.
	receiver ?CallReceiverInfo

	// arguments contains call arguments in source order.
	arguments []CallArgumentInfo

	// block describes a literal block or an argument passed with `&`.
	block ?CallBlockInfo

	// safe_navigation is true when the call uses Ruby's `&.` operator.
	safe_navigation bool

	// text is the source text covered by the call node.
	text string

	// node is the strongly typed Prism call node.
	node ast.Node
}

// ParameterKind identifies the Ruby method parameter form.
pub enum ParameterKind {
	required
	optional
	rest
	required_keyword
	optional_keyword
	keyword_rest
	block
	forwarding
	no_keywords
	unknown
}

// ParameterInfo describes a Ruby method parameter found in a method signature.
pub struct ParameterInfo {
pub:
	// name is the parameter name when Prism exposes one.
	name string

	// text is the source text covered by the parameter node.
	text string

	// kind identifies the Ruby parameter form.
	kind ParameterKind

	// node is the strongly typed Prism parameter node.
	node ast.Node
}

// ExpressionInfo describes a Ruby expression used by a high-level analysis result.
pub struct ExpressionInfo {
pub:
	// text is the source text covered by the expression node.
	text string

	// node is the strongly typed Prism expression node.
	node ast.Node
}

// ControlFlowKind identifies an explicit Ruby control-flow expression.
pub enum ControlFlowKind {
	return_
	break_
	next_
	redo
	retry
	yield_
	super_
	forwarding_super
}

// ControlFlowInfo describes an explicit Ruby control-flow expression.
pub struct ControlFlowInfo {
pub:
	// kind identifies the control-flow expression.
	kind ControlFlowKind

	// arguments contains explicit arguments in source order.
	arguments []ExpressionInfo

	// block describes the block passed to `super` when present.
	block ?ExpressionInfo

	// forwards_arguments is true for a forwarding `super` expression.
	forwards_arguments bool

	// text is the source text covered by the control-flow node.
	text string

	// node is the strongly typed Prism control-flow node.
	node ast.Node
}

// MethodVisibility identifies the declared visibility of a Ruby method.
pub enum MethodVisibility {
	public_
	protected_
	private_
	unknown
}

// MethodInfo describes a Ruby method definition found in a parsed source.
pub struct MethodInfo {
pub:
	// name is the method name being defined.
	name string

	// receiver describes the explicit receiver of a singleton method.
	receiver ?ExpressionInfo

	// singleton is true when the method definition has an explicit receiver.
	singleton bool

	// visibility is the method visibility when known from its containing scope.
	visibility MethodVisibility

	// parameters contains method parameters in Ruby signature order.
	parameters []ParameterInfo

	// body describes the method body when present.
	body ?ExpressionInfo

	// calls contains method calls made from this method body.
	calls []CallInfo

	// control_flows contains direct control-flow expressions from this method body.
	control_flows []ControlFlowInfo

	// text is the source text covered by the method definition node.
	text string

	// node is the strongly typed Prism def node.
	node ast.Node
}

// DefinitionKind identifies a Ruby namespace definition.
pub enum DefinitionKind {
	class_definition
	module_definition
}

// DefinitionInfo describes a directly nested Ruby class or module definition.
pub struct DefinitionInfo {
pub:
	// kind identifies whether the definition is a class or module.
	kind DefinitionKind

	// name is the terminal constant name of the definition.
	name string

	// constant_path is the complete source text of the definition's constant path.
	constant_path string

	// text is the source text covered by the definition node.
	text string

	// node is the strongly typed Prism class or module node.
	node ast.Node
}

// ScopeKind identifies a Ruby lexical scope represented in a scope path.
pub enum ScopeKind {
	class_
	module_
	singleton_class
	method
}

// ScopeInfo describes one lexical scope enclosing an AST node.
pub struct ScopeInfo {
pub:
	// kind identifies the Ruby scope form.
	kind ScopeKind

	// name is the scope name or singleton class expression.
	name string

	// constant_path is the complete class or module constant path when available.
	constant_path string

	// text is the source text covered by the scope node.
	text string

	// node is the strongly typed Prism scope node.
	node ast.Node
}

// ConstantUsage identifies how Ruby source uses a constant.
pub enum ConstantUsage {
	read
	write
	target
	declaration
}

// ConstantInfo describes a normalized Ruby constant reference or definition.
pub struct ConstantInfo {
pub:
	// name is the terminal constant name.
	name string

	// path is the complete constant path represented by the node.
	path string

	// usage identifies whether the constant is read, written, targeted, or declared.
	usage ConstantUsage

	// value describes the assigned value for constant writes when present.
	value ?ExpressionInfo

	// text is the source text covered by the reporting node.
	text string

	// node is the strongly typed Prism node reported for this constant.
	node ast.Node
}

// VariableKind identifies the namespace of a Ruby variable.
pub enum VariableKind {
	local
	instance
	class_
	global
}

// VariableUsage identifies how Ruby source uses a variable.
pub enum VariableUsage {
	read
	write
	target
}

// VariableInfo describes a Ruby variable read, write, or assignment target.
pub struct VariableInfo {
pub:
	// name is the variable name including Ruby's `@`, `@@`, or `$` prefix.
	name string

	// kind identifies the variable namespace.
	kind VariableKind

	// usage identifies whether the variable is read, written, or targeted.
	usage VariableUsage

	// depth is the local variable lexical depth when Prism provides one.
	depth ?u32

	// value describes the assigned value for variable writes when present.
	value ?ExpressionInfo

	// text is the source text covered by the variable node.
	text string

	// node is the strongly typed Prism variable node.
	node ast.Node
}

// DependencyKind identifies a Ruby source dependency declaration.
pub enum DependencyKind {
	require_
	require_relative
	load
	autoload
}

// DependencyInfo describes a dependency declaration found in Ruby source.
pub struct DependencyInfo {
pub:
	// kind identifies the Ruby dependency-loading method.
	kind DependencyKind

	// path is the statically known dependency path when available.
	path string

	// constant_name is the constant registered by `autoload` when statically known.
	constant_name string

	// dynamic is true when the dependency path is not a plain string literal.
	dynamic bool

	// call is the high-level call that declares the dependency.
	call CallInfo
}

// AliasKind identifies the namespace changed by a Ruby `alias` expression.
pub enum AliasKind {
	method
	global_variable
}

// NameInfo describes a static or dynamic Ruby name expression.
pub struct NameInfo {
pub:
	// name is the statically known name when available.
	name string

	// dynamic is true when the name contains a runtime expression.
	dynamic bool

	// text is the source text covered by the name node.
	text string

	// node is the strongly typed Prism name node.
	node ast.Node
}

// AliasInfo describes a Ruby method or global variable alias expression.
pub struct AliasInfo {
pub:
	// kind identifies whether the alias changes a method or global variable name.
	kind AliasKind

	// new_name describes the new name introduced by the alias.
	new_name NameInfo

	// old_name describes the existing name referenced by the alias.
	old_name NameInfo

	// dynamic is true when either alias name is dynamic.
	dynamic bool

	// text is the source text covered by the alias node.
	text string

	// node is the strongly typed Prism alias node.
	node ast.Node
}

// UndefInfo describes a Ruby `undef` expression.
pub struct UndefInfo {
pub:
	// names contains names removed by the expression in source order.
	names []NameInfo

	// text is the source text covered by the undef node.
	text string

	// node is the strongly typed Prism undef node.
	node ast.Node
}

// RescueInfo describes a Ruby rescue clause or modifier expression.
pub struct RescueInfo {
pub:
	// exceptions contains explicitly rescued exception expressions.
	exceptions []ExpressionInfo

	// reference describes the variable receiving the exception when present.
	reference ?ExpressionInfo

	// body describes the rescue body or modifier fallback expression.
	body ?ExpressionInfo

	// protected_expression describes the left side of a rescue modifier.
	protected_expression ?ExpressionInfo

	// modifier is true for an inline rescue modifier expression.
	modifier bool

	// text is the source text covered by the rescue node.
	text string

	// node is the strongly typed Prism rescue node.
	node ast.Node
}

// ExceptionRegionInfo describes a Ruby begin region with exception clauses.
pub struct ExceptionRegionInfo {
pub:
	// body describes statements protected by the begin region.
	body ?ExpressionInfo

	// rescues contains rescue clauses in source order.
	rescues []RescueInfo

	// else_body describes statements run when no exception is rescued.
	else_body ?ExpressionInfo

	// ensure_body describes statements that always run when leaving the region.
	ensure_body ?ExpressionInfo

	// text is the source text covered by the begin node.
	text string

	// node is the strongly typed Prism begin node.
	node ast.Node
}

// ClassInfo describes a Ruby class definition found in a parsed source.
pub struct ClassInfo {
pub:
	// name is the terminal constant name of the class.
	name string

	// constant_path is the complete source text of the class constant path.
	constant_path string

	// superclass describes the superclass expression when present.
	superclass ?ExpressionInfo

	// methods contains methods defined directly in the class scope.
	methods []MethodInfo

	// nested_definitions contains classes and modules defined directly in this class.
	nested_definitions []DefinitionInfo

	// text is the source text covered by the class definition node.
	text string

	// node is the strongly typed Prism class node.
	node ast.Node
}

// ModuleInfo describes a Ruby module definition found in a parsed source.
pub struct ModuleInfo {
pub:
	// name is the terminal constant name of the module.
	name string

	// constant_path is the complete source text of the module constant path.
	constant_path string

	// methods contains methods defined directly in the module scope.
	methods []MethodInfo

	// nested_definitions contains classes and modules defined directly in this module.
	nested_definitions []DefinitionInfo

	// text is the source text covered by the module definition node.
	text string

	// node is the strongly typed Prism module node.
	node ast.Node
}

// calls returns Ruby method calls found in the decoded AST.
pub fn (result Analyzer) calls() []CallInfo {
	mut calls := []CallInfo{}

	for node in result.find_all(.call) {
		calls << result.call_info(node) or { continue }
	}

	return calls
}

// methods returns Ruby method definitions found in the decoded AST.
pub fn (result Analyzer) methods() []MethodInfo {
	mut methods := []MethodInfo{}

	for node in result.find_all(.def) {
		methods << result.method_info(node, .unknown) or { continue }
	}

	return methods
}

// classes returns Ruby class definitions found in the decoded AST.
pub fn (result Analyzer) classes() []ClassInfo {
	mut classes := []ClassInfo{}

	for node in result.find_all(.class) {
		classes << result.class_info(node) or { continue }
	}

	return classes
}

// modules returns Ruby module definitions found in the decoded AST.
pub fn (result Analyzer) modules() []ModuleInfo {
	mut modules := []ModuleInfo{}

	for node in result.find_all(.module_) {
		modules << result.module_info(node) or { continue }
	}

	return modules
}

// constants returns normalized Ruby constant reads, writes, targets, and declarations.
pub fn (result Analyzer) constants() []ConstantInfo {
	mut constants := []ConstantInfo{}

	result.collect_constants(result.root, mut constants)

	return constants
}

// variables returns Ruby local, instance, class, and global variable usages.
pub fn (result Analyzer) variables() []VariableInfo {
	mut variables := []VariableInfo{}

	result.collect_variables(result.root, mut variables)

	return variables
}

// dependencies returns explicit Ruby dependency-loading calls from the decoded AST.
pub fn (result Analyzer) dependencies() []DependencyInfo {
	mut dependencies := []DependencyInfo{}

	for call in result.calls() {
		dependency := result.dependency_info(call) or { continue }

		dependencies << dependency
	}

	return dependencies
}

// control_flows returns explicit Ruby control-flow expressions from the decoded AST.
pub fn (result Analyzer) control_flows() []ControlFlowInfo {
	mut nodes := []ast.Node{}

	collect_control_flow_nodes(result.root, false, mut nodes)
	sort_nodes_by_source(mut nodes)

	return result.control_flow_infos(nodes)
}

// aliases returns Ruby method and global variable alias expressions.
pub fn (result Analyzer) aliases() []AliasInfo {
	mut aliases := []AliasInfo{}

	for node in result.find_all(.alias_method) {
		aliases << result.alias_info(node, .method) or { continue }
	}

	for node in result.find_all(.alias_global_variable) {
		aliases << result.alias_info(node, .global_variable) or { continue }
	}

	sort_aliases_by_source(mut aliases)

	return aliases
}

// undefs returns Ruby method undef expressions.
pub fn (result Analyzer) undefs() []UndefInfo {
	mut undefs := []UndefInfo{}

	for node in result.find_all(.undef) {
		undefs << result.undef_info(node) or { continue }
	}

	return undefs
}

// exception_regions returns Ruby begin regions that contain rescue, else, or ensure clauses.
pub fn (result Analyzer) exception_regions() []ExceptionRegionInfo {
	mut regions := []ExceptionRegionInfo{}

	for node in result.find_all(.begin) {
		if !has_exception_clause(node) {
			continue
		}

		regions << result.exception_region_info(node) or { continue }
	}

	return regions
}

// rescues returns Ruby rescue clauses and modifier rescue expressions.
pub fn (result Analyzer) rescues() []RescueInfo {
	mut rescues := []RescueInfo{}

	for node in result.find_all(.rescue) {
		rescues << result.rescue_info(node, false) or { continue }
	}

	for node in result.find_all(.rescue_modifier) {
		rescues << result.rescue_info(node, true) or { continue }
	}

	sort_rescues_by_source(mut rescues)

	return rescues
}

// scope_path returns lexical scopes enclosing node from outermost to innermost.
pub fn (result Analyzer) scope_path(node ast.Node) ![]ScopeInfo {
	index := result.analysis_index()
	scope_nodes := index.scope_nodes(node)!
	mut scopes := []ScopeInfo{cap: scope_nodes.len}

	for scope_node in scope_nodes {
		scopes << result.scope_info(scope_node)!
	}

	return scopes
}

// enclosing_class returns the nearest class enclosing node.
pub fn (result Analyzer) enclosing_class(node ast.Node) ?ClassInfo {
	scopes := result.scope_path(node) or { return none }

	for offset in 0 .. scopes.len {
		scope := scopes[scopes.len - 1 - offset]

		if scope.kind == .class_ {
			return result.class_info(scope.node) or { return none }
		}
	}

	return none
}

// enclosing_module returns the nearest module enclosing node.
pub fn (result Analyzer) enclosing_module(node ast.Node) ?ModuleInfo {
	scopes := result.scope_path(node) or { return none }

	for offset in 0 .. scopes.len {
		scope := scopes[scopes.len - 1 - offset]

		if scope.kind == .module_ {
			return result.module_info(scope.node) or { return none }
		}
	}

	return none
}

// enclosing_method returns the nearest method enclosing node.
pub fn (result Analyzer) enclosing_method(node ast.Node) ?MethodInfo {
	scopes := result.scope_path(node) or { return none }

	for offset in 0 .. scopes.len {
		scope_index := scopes.len - 1 - offset
		scope := scopes[scope_index]

		if scope.kind != .method {
			continue
		}

		for owner_offset in 0 .. scope_index {
			owner := scopes[scope_index - 1 - owner_offset]

			if owner.kind !in [.class_, .module_, .singleton_class] {
				continue
			}

			for method in result.scope_methods(owner.node) {
				if method.node.base().id == scope.node.base().id {
					return method
				}
			}
		}

		return result.method_info(scope.node, .unknown) or { return none }
	}

	return none
}

// method_info builds a high-level method description from a DefNode.
fn (result Analyzer) method_info(node ast.Node, visibility MethodVisibility) !MethodInfo {
	def_node := node.as_def()!
	name := result.constant_value(def_node.name)!
	receiver := result.optional_expression(def_node.receiver)
	parameters := result.method_parameters(node)
	body := result.optional_expression(def_node.body)
	calls := result.method_calls(node)
	control_flows := result.method_control_flows(node)
	text := result.node_text(node) or { '' }

	return MethodInfo{
		name:          name
		receiver:      receiver
		singleton:     receiver != none
		visibility:    visibility
		parameters:    parameters
		body:          body
		calls:         calls
		control_flows: control_flows
		text:          text
		node:          node
	}
}

// call_info builds a high-level call description from a CallNode.
fn (result Analyzer) call_info(node ast.Node) !CallInfo {
	call_node := node.as_call()!
	name := result.constant_value(call_node.name)!
	receiver := result.call_receiver(node)
	arguments := result.call_arguments(node)
	block := result.call_block(node)
	text := result.node_text(node) or { '' }

	return CallInfo{
		name:            name
		receiver:        receiver
		arguments:       arguments
		block:           block
		safe_navigation: call_node.has_flag(ast.call_node_safe_navigation)
		text:            text
		node:            node
	}
}

// class_info builds a high-level class description from a ClassNode.
fn (result Analyzer) class_info(node ast.Node) !ClassInfo {
	class_node := node.as_class()!
	name := result.constant_value(class_node.name)!
	constant_path := result.node_text(class_node.constant_path) or { name }
	superclass := result.optional_expression(class_node.superclass)
	methods := result.scope_methods(node)
	nested_definitions := result.scope_nested_definitions(node)
	text := result.node_text(node) or { '' }

	return ClassInfo{
		name:               name
		constant_path:      constant_path
		superclass:         superclass
		methods:            methods
		nested_definitions: nested_definitions
		text:               text
		node:               node
	}
}

// module_info builds a high-level module description from a ModuleNode.
fn (result Analyzer) module_info(node ast.Node) !ModuleInfo {
	module_node := node.as_module_()!
	name := result.constant_value(module_node.name)!
	constant_path := result.node_text(module_node.constant_path) or { name }
	methods := result.scope_methods(node)
	nested_definitions := result.scope_nested_definitions(node)
	text := result.node_text(node) or { '' }

	return ModuleInfo{
		name:               name
		constant_path:      constant_path
		methods:            methods
		nested_definitions: nested_definitions
		text:               text
		node:               node
	}
}

// expression returns source and node information for a required expression.
fn (result Analyzer) expression(node ast.Node) ExpressionInfo {
	return ExpressionInfo{
		text: result.node_text(node) or { '' }
		node: node
	}
}

// optional_expression returns source and node information for an optional expression.
fn (result Analyzer) optional_expression(optional_node ?ast.Node) ?ExpressionInfo {
	node := optional_node or { return none }

	return result.expression(node)
}

// expressions returns source and node information for a list of expressions.
fn (result Analyzer) expressions(nodes []ast.Node) []ExpressionInfo {
	mut expressions := []ExpressionInfo{cap: nodes.len}

	for node in nodes {
		expressions << result.expression(node)
	}

	return expressions
}
