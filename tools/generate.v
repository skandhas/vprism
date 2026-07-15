module main

import os
import strings
import yaml

const config_path = os.join_path('thirdparty', 'prism', 'config.yml')

struct PrismConfig {
	errors   []string
	warnings []string
	tokens   []TokenDef
	flags    []FlagDef
	nodes    []NodeDef
}

struct TokenDef {
	name    string
	value   int
	comment string
}

struct FlagDef {
	name    string
	values  []FlagValueDef
	comment string
}

struct FlagValueDef {
	name    string
	comment string
}

struct NodeDef {
	name    string
	flags   string
	fields  []FieldDef
	comment string
}

struct FieldDef {
	name      string
	typ       string
	kind      yaml.Any
	comment   string
	v_name    string
	v_type    string
	optional  bool
	array     bool
	base_type string
}

// main loads the pinned Prism config and writes generated V source files.
fn main() {
	if !os.exists(config_path) {
		eprintln('missing ${config_path}')
		exit(1)
	}

	config := load_config(config_path) or {
		eprintln(err.msg())
		exit(1)
	}

	write_node_kind(config.nodes) or {
		eprintln(err.msg())
		exit(1)
	}
	write_nodes(config.nodes) or {
		eprintln(err.msg())
		exit(1)
	}
	write_node_methods(config.nodes) or {
		eprintln(err.msg())
		exit(1)
	}
	write_node_decoder(config.nodes) or {
		eprintln(err.msg())
		exit(1)
	}
	write_token_kind(config.tokens) or {
		eprintln(err.msg())
		exit(1)
	}
	write_diagnostic_kind(config.errors, config.warnings) or {
		eprintln(err.msg())
		exit(1)
	}
	write_flags(config.flags, config.nodes) or {
		eprintln(err.msg())
		exit(1)
	}

	println('loaded ${config_path}')
	println('errors: ${config.errors.len}')
	println('warnings: ${config.warnings.len}')
	println('tokens: ${config.tokens.len}')
	println('flags: ${config.flags.len}')
	println('nodes: ${config.nodes.len}')
	println('generated generated/node_kind.v')
	println('generated ast/node_kind.v')
	println('generated generated/nodes.v')
	println('generated ast/nodes.v')
	println('generated generated/node_methods.v')
	println('generated ast/node_methods.v')
	println('generated generated/node_decode.v')
	println('generated serialize/node_decode.v')
	println('generated generated/token_kind.v')
	println('generated serialize/token_kind.v')
	println('generated generated/diagnostic_kind.v')
	println('generated serialize/diagnostic_kind.v')
	println('generated generated/flags.v')
	println('generated ast/flags.v')
}

// load_config parses Prism's YAML config into the normalized generator model.
fn load_config(path string) !PrismConfig {
	doc := yaml.parse_file(path)!

	return PrismConfig{
		errors:   read_string_array(doc.value('errors'))
		warnings: read_string_array(doc.value('warnings'))
		tokens:   read_tokens(doc.value('tokens'))
		flags:    read_flags(doc.value('flags'))
		nodes:    read_nodes(doc.value('nodes'))
	}
}

// read_string_array converts a YAML sequence into a V string array.
fn read_string_array(value yaml.Any) []string {
	mut out := []string{}

	for item in value.array() {
		out << item.string()
	}

	return out
}

// read_tokens converts Prism token entries into token definitions.
fn read_tokens(value yaml.Any) []TokenDef {
	mut out := []TokenDef{}

	for item in value.array() {
		out << TokenDef{
			name:    item.value('name').string()
			value:   item.value('value').int()
			comment: optional_string(item, 'comment')
		}
	}

	return out
}

// read_flags converts Prism flag entries into flag definitions.
fn read_flags(value yaml.Any) []FlagDef {
	mut out := []FlagDef{}

	for item in value.array() {
		out << FlagDef{
			name:    item.value('name').string()
			values:  read_flag_values(item.value('values'))
			comment: optional_string(item, 'comment')
		}
	}

	return out
}

// read_flag_values converts values inside a Prism flag definition.
fn read_flag_values(value yaml.Any) []FlagValueDef {
	mut out := []FlagValueDef{}

	for item in value.array() {
		out << FlagValueDef{
			name:    item.value('name').string()
			comment: optional_string(item, 'comment')
		}
	}

	return out
}

// read_nodes converts Prism node entries into node definitions.
fn read_nodes(value yaml.Any) []NodeDef {
	mut out := []NodeDef{}

	for item in value.array() {
		out << NodeDef{
			name:    item.value('name').string()
			flags:   optional_string(item, 'flags')
			fields:  read_fields(item.value('fields'))
			comment: optional_string(item, 'comment')
		}
	}

	return out
}

// read_fields converts Prism field entries into field definitions.
fn read_fields(value yaml.Any) []FieldDef {
	if value is yaml.Null {
		return []FieldDef{}
	}

	mut out := []FieldDef{}

	for item in value.array() {
		prism_type := item.value('type').string()
		base_type := normalize_base_type(prism_type)

		out << FieldDef{
			name:      item.value('name').string()
			typ:       prism_type
			kind:      item.value('kind')
			comment:   optional_string(item, 'comment')
			v_name:    to_v_field_name(item.value('name').string())
			v_type:    to_v_type(prism_type)
			optional:  prism_type.ends_with('?')
			array:     prism_type.ends_with('[]')
			base_type: base_type
		}
	}

	return out
}

// optional_string reads a string key from a YAML value or returns an empty string.
fn optional_string(value yaml.Any, key string) string {
	return value.value_opt(key) or { return '' }.string()
}

// normalize_base_type removes Prism optional and array suffixes from a field type.
fn normalize_base_type(prism_type string) string {
	if prism_type.ends_with('?') {
		return prism_type[..prism_type.len - 1]
	}

	if prism_type.ends_with('[]') {
		return prism_type[..prism_type.len - 2]
	}

	return prism_type
}

// to_v_type maps a Prism serialized field type to the public V AST field type.
fn to_v_type(prism_type string) string {
	base_type := normalize_base_type(prism_type)
	mut v_type := match base_type {
		'node' { 'Node' }
		'location' { 'Location' }
		'constant' { 'ConstantId' }
		'string' { 'string' }
		'integer' { 'Integer' }
		'double' { 'f64' }
		'uint8' { 'u8' }
		'uint32' { 'u32' }
		else { 'UnknownField' }
	}

	if prism_type.ends_with('[]') {
		return '[]${v_type}'
	}

	if prism_type.ends_with('?') {
		v_type = '?${v_type}'
	}

	return v_type
}

// to_v_field_name converts a Prism field name into a V-safe field name.
fn to_v_field_name(name string) string {
	return v_keyword_safe(to_snake_case(name))
}

// to_enum_name converts a Prism node name into a V enum value.
fn to_enum_name(node_name string) string {
	mut name := node_name

	if name.ends_with('Node') && name.len > 4 {
		name = name[..name.len - 4]
	}

	return v_keyword_safe(to_snake_case(name))
}

// to_token_enum_name converts a Prism token name into a V enum value.
fn to_token_enum_name(token_name string) string {
	return v_keyword_safe(token_name.to_lower())
}

// to_diagnostic_enum_name converts a Prism diagnostic name into a V enum value.
fn to_diagnostic_enum_name(prefix string, diagnostic_name string) string {
	return v_keyword_safe('${prefix}_${diagnostic_name.to_lower()}')
}

// to_flag_const_name converts a Prism flag group and value into a V constant name.
fn to_flag_const_name(flag FlagDef, value FlagValueDef) string {
	group := flag_group_name(flag)

	return '${group}_${value.name.to_lower()}'
}

// flag_group_name converts a Prism flag group name into a concise V identifier prefix.
fn flag_group_name(flag FlagDef) string {
	mut name := flag.name

	if name.ends_with('Flags') && name.len > 5 {
		name = name[..name.len - 5]
	}

	return to_snake_case(name)
}

// token_value returns the explicit Prism token value for a token index.
fn token_value(token TokenDef, index int) int {
	if token.value != 0 {
		return token.value
	}

	return index + 1
}

// to_snake_case converts Prism's PascalCase and camelCase names to snake_case.
fn to_snake_case(name string) string {
	mut out := strings.new_builder(name.len + 8)

	for i, ch in name.runes() {
		if ch >= `A` && ch <= `Z` {
			if i > 0 {
				out.write_u8(`_`)
			}

			out.write_rune(ch.to_lower())
		} else {
			out.write_rune(ch)
		}
	}

	return out.str()
}

// v_keyword_safe avoids V keywords in generated identifiers.
fn v_keyword_safe(name string) string {
	return match name {
		'none', 'type', 'map', 'module', 'struct', 'interface', 'enum', 'fn', 'match', 'select',
		'or', 'is', 'as', 'in', 'not', 'return', 'if', 'else', 'for', 'go', 'defer', 'unsafe',
		'nil', 'true', 'false' {
			'${name}_'
		}
		'default' {
			'default_'
		}
		else {
			name
		}
	}
}

// write_diagnostic_kind writes the generated DiagnosticKind enum into generated and live paths.
fn write_diagnostic_kind(errors []string, warnings []string) ! {
	mut out := strings.new_builder(32768)

	out.writeln('// Code generated by tools/generate.v; DO NOT EDIT.')
	out.writeln('module serialize')
	out.writeln('')
	out.writeln('// DiagnosticKind identifies a Prism parser diagnostic id.')
	out.writeln('pub enum DiagnosticKind {')

	for i, error_name in errors {
		out.writeln('\t// PM_ERR_${error_name}')
		out.writeln('\t${to_diagnostic_enum_name('err', error_name)} = ${i}')
	}

	for i, warning_name in warnings {
		out.writeln('\t// PM_WARN_${warning_name}')
		out.writeln('\t${to_diagnostic_enum_name('warn', warning_name)} = ${errors.len + i}')
	}

	out.writeln('}')
	out.writeln('')
	out.writeln('// diagnostic_kind_from_value converts a serialized Prism diagnostic id to DiagnosticKind.')
	out.writeln('pub fn diagnostic_kind_from_value(value u32) !DiagnosticKind {')
	out.writeln('\treturn match value {')

	for i, error_name in errors {
		out.writeln('\t\t${i} { .${to_diagnostic_enum_name('err', error_name)} }')
	}

	for i, warning_name in warnings {
		out.writeln('\t\t${errors.len + i} { .${to_diagnostic_enum_name('warn', warning_name)} }')
	}

	out.writeln("\t\telse { return error('unknown Prism diagnostic kind: \${value}') }")
	out.writeln('\t}')
	out.writeln('}')
	out.writeln('')
	out.writeln('// is_error reports whether this diagnostic kind is a Prism parser error.')
	out.writeln('pub fn (kind DiagnosticKind) is_error() bool {')
	out.writeln('\treturn int(kind) < ${errors.len}')
	out.writeln('}')
	out.writeln('')
	out.writeln('// is_warning reports whether this diagnostic kind is a Prism parser warning.')
	out.writeln('pub fn (kind DiagnosticKind) is_warning() bool {')
	out.writeln('\treturn int(kind) >= ${errors.len}')
	out.writeln('}')

	content := out.str()

	os.write_file(os.join_path('generated', 'diagnostic_kind.v'), content)!
	os.write_file(os.join_path('serialize', 'diagnostic_kind.v'), content)!
}

// write_flags writes generated typed Prism node flag helpers.
fn write_flags(flags []FlagDef, nodes []NodeDef) ! {
	mut out := strings.new_builder(32768)

	out.writeln('// Code generated by tools/generate.v; DO NOT EDIT.')
	out.writeln('module ast')
	out.writeln('')
	out.writeln('// NodeFlags stores Prism node flags as a bitset.')
	out.writeln('pub type NodeFlags = u32')
	out.writeln('')
	out.writeln('// node_flag_newline indicates that a node starts on a new line.')
	out.writeln('pub const node_flag_newline = NodeFlags(0x1)')
	out.writeln('')
	out.writeln('// node_flag_static_literal indicates that a node is a static literal.')
	out.writeln('pub const node_flag_static_literal = NodeFlags(0x2)')
	out.writeln('')
	out.writeln('// has reports whether this bitset contains flag.')
	out.writeln('pub fn (flags NodeFlags) has(flag NodeFlags) bool {')
	out.writeln('\treturn u32(flags) & u32(flag) != 0')
	out.writeln('}')
	out.writeln('')
	out.writeln('// has_flag reports whether this node base contains flag.')
	out.writeln('pub fn (base NodeBase) has_flag(flag NodeFlags) bool {')
	out.writeln('\treturn base.flags.has(flag)')
	out.writeln('}')
	out.writeln('')

	for flag in flags {
		write_flag_group(mut out, flag)
		out.writeln('')
	}

	for node in nodes {
		if node.flags.len == 0 {
			continue
		}

		out.writeln('// flags_value returns typed flags for ${node.name}.')
		out.writeln('pub fn (node ${node.name}) flags_value() ${node.flags} {')
		out.writeln('\treturn ${node.flags}(node.base.flags)')
		out.writeln('}')
		out.writeln('')
		out.writeln('// has_flag reports whether ${node.name} has flag.')
		out.writeln('pub fn (node ${node.name}) has_flag(flag ${node.flags}) bool {')
		out.writeln('\treturn node.flags_value().has(flag)')
		out.writeln('}')
		out.writeln('')
	}

	content := out.str()

	os.write_file(os.join_path('generated', 'flags.v'), content)!
	os.write_file(os.join_path('ast', 'flags.v'), content)!
}

// write_flag_group writes one typed flag bitset and its constants.
fn write_flag_group(mut out strings.Builder, flag FlagDef) {
	write_doc_comment(mut out, flag.name, flag.comment)
	out.writeln('pub type ${flag.name} = u32')
	out.writeln('')

	for i, value in flag.values {
		write_top_level_comment(mut out, value.comment)
		out.writeln('pub const ${to_flag_const_name(flag, value)} = ${flag.name}(1 << ${i + 2})')
		out.writeln('')
	}

	out.writeln('// has reports whether this bitset contains flag.')
	out.writeln('pub fn (flags ${flag.name}) has(flag ${flag.name}) bool {')
	out.writeln('\treturn u32(flags) & u32(flag) != 0')
	out.writeln('}')
	out.writeln('')
	out.writeln('// node_flags returns this typed bitset as common node flags.')
	out.writeln('pub fn (flags ${flag.name}) node_flags() NodeFlags {')
	out.writeln('\treturn NodeFlags(flags)')
	out.writeln('}')
}

// write_top_level_comment writes a generated top-level declaration comment.
fn write_top_level_comment(mut out strings.Builder, comment string) {
	cleaned := clean_comment(comment)

	if cleaned.len == 0 {
		return
	}

	lines := cleaned.split_into_lines()

	for line in lines {
		out.writeln('// ${line}')
	}
}

// write_token_kind writes the generated TokenKind enum into generated and live paths.
fn write_token_kind(tokens []TokenDef) ! {
	mut out := strings.new_builder(16384)

	out.writeln('// Code generated by tools/generate.v; DO NOT EDIT.')
	out.writeln('module serialize')
	out.writeln('')
	out.writeln('// TokenKind identifies a Prism lexer token kind.')
	out.writeln('pub enum TokenKind {')
	out.writeln('\t// unknown is reserved for invalid or absent token kinds.')
	out.writeln('\tunknown = 0')

	for i, token in tokens {
		write_field_comment(mut out, token.comment)
		out.writeln('\t${to_token_enum_name(token.name)} = ${token_value(token, i)}')
	}

	out.writeln('}')
	out.writeln('')
	out.writeln('// token_kind_from_value converts a serialized Prism token value to TokenKind.')
	out.writeln('pub fn token_kind_from_value(value u32) !TokenKind {')
	out.writeln('\treturn match value {')
	out.writeln('\t\t0 { .unknown }')

	for i, token in tokens {
		out.writeln('\t\t${token_value(token, i)} { .${to_token_enum_name(token.name)} }')
	}

	out.writeln("\t\telse { return error('unknown Prism token kind: \${value}') }")
	out.writeln('\t}')
	out.writeln('}')

	content := out.str()

	os.write_file(os.join_path('generated', 'token_kind.v'), content)!
	os.write_file(os.join_path('serialize', 'token_kind.v'), content)!
}

// write_node_kind writes the generated NodeKind enum into generated and live paths.
fn write_node_kind(nodes []NodeDef) ! {
	mut out := strings.new_builder(4096)

	out.writeln('// Code generated by tools/generate.v; DO NOT EDIT.')
	out.writeln('module ast')
	out.writeln('')
	out.writeln('// NodeKind identifies a Prism AST node kind.')
	out.writeln('pub enum NodeKind {')
	out.writeln('\tunknown')

	for node in nodes {
		out.writeln('\t${to_enum_name(node.name)}')
	}

	out.writeln('}')

	content := out.str()

	os.write_file(os.join_path('generated', 'node_kind.v'), content)!
	os.write_file(os.join_path('ast', 'node_kind.v'), content)!
}

// write_nodes writes one V struct for each Prism AST node.
fn write_nodes(nodes []NodeDef) ! {
	mut out := strings.new_builder(65536)

	out.writeln('// Code generated by tools/generate.v; DO NOT EDIT.')
	out.writeln('module ast')
	out.writeln('')
	out.writeln('// Node contains every concrete Prism AST node.')
	out.writeln('pub type Node = ${nodes[0].name}')

	for node in nodes[1..] {
		out.writeln('\t| ${node.name}')
	}

	out.writeln('')

	for node in nodes {
		write_node_struct(mut out, node)
		out.writeln('')
	}

	content := out.str()

	os.write_file(os.join_path('generated', 'nodes.v'), content)!
	os.write_file(os.join_path('ast', 'nodes.v'), content)!
}

// write_node_methods writes common traversal and concrete conversion methods.
fn write_node_methods(nodes []NodeDef) ! {
	mut out := strings.new_builder(65536)

	out.writeln('// Code generated by tools/generate.v; DO NOT EDIT.')
	out.writeln('module ast')
	out.writeln('')
	out.writeln('// base returns metadata shared by a concrete node.')
	out.writeln('pub fn (node Node) base() NodeBase {')
	out.writeln('\tmatch node {')

	for node in nodes {
		out.writeln('\t\t${node.name} { return node.base }')
	}

	out.writeln('\t}')
	out.writeln('}')
	out.writeln('')
	out.writeln('// is_kind reports whether this node has kind.')
	out.writeln('pub fn (node Node) is_kind(kind NodeKind) bool {')
	out.writeln('\treturn node.base().kind == kind')
	out.writeln('}')
	out.writeln('')
	out.writeln('// child_nodes returns direct child nodes in field order.')
	out.writeln('pub fn (node Node) child_nodes() []Node {')
	out.writeln('\tmut children := []Node{}')
	out.writeln('')
	out.writeln('\tmatch node {')

	for node in nodes {
		out.writeln('\t\t${node.name} {')

		for field in node.fields {
			match field.typ {
				'node' {
					out.writeln('\t\t\tchildren << node.${field.v_name}')
				}
				'node?' {
					out.writeln('\t\t\tif child := node.${field.v_name} {')
					out.writeln('\t\t\t\tchildren << child')
					out.writeln('\t\t\t}')
				}
				'node[]' {
					out.writeln('\t\t\tchildren << node.${field.v_name}')
				}
				else {}
			}
		}

		out.writeln('\t\t}')
	}

	out.writeln('\t}')
	out.writeln('')
	out.writeln('\treturn children')
	out.writeln('}')
	out.writeln('')
	out.writeln('// descendants returns all descendant nodes in depth-first order.')
	out.writeln('pub fn (node Node) descendants() []Node {')
	out.writeln('\tmut descendants := []Node{}')
	out.writeln('')
	out.writeln('\tfor child in node.child_nodes() {')
	out.writeln('\t\tdescendants << child')
	out.writeln('\t\tdescendants << child.descendants()')
	out.writeln('\t}')
	out.writeln('')
	out.writeln('\treturn descendants')
	out.writeln('}')
	out.writeln('')
	out.writeln('// find_first returns the first node with kind in depth-first order.')
	out.writeln('pub fn (node Node) find_first(kind NodeKind) ?Node {')
	out.writeln('\tif node.base().kind == kind {')
	out.writeln('\t\treturn node')
	out.writeln('\t}')
	out.writeln('')
	out.writeln('\tfor child in node.child_nodes() {')
	out.writeln('\t\tif found := child.find_first(kind) { return found }')
	out.writeln('\t}')
	out.writeln('')
	out.writeln('\treturn none')
	out.writeln('}')
	out.writeln('')
	out.writeln('// find_all returns all nodes with kind in depth-first order.')
	out.writeln('pub fn (node Node) find_all(kind NodeKind) []Node {')
	out.writeln('\tmut matches := []Node{}')
	out.writeln('\tnode.collect_kind(kind, mut matches)')
	out.writeln('\treturn matches')
	out.writeln('}')
	out.writeln('')
	out.writeln('// walk visits this node and every allowed descendant.')
	out.writeln('pub fn (node &Node) walk(mut visitor Visitor) ! {')
	out.writeln('\tvisitor.visit(node)!')
	out.writeln('\tfor child in node.child_nodes() { child.walk(mut visitor)! }')
	out.writeln('}')
	out.writeln('')
	out.writeln('// collect_kind appends nodes matching kind.')
	out.writeln('fn (node Node) collect_kind(kind NodeKind, mut matches []Node) {')
	out.writeln('\tif node.base().kind == kind { matches << node }')
	out.writeln('\tfor child in node.child_nodes() { child.collect_kind(kind, mut matches) }')
	out.writeln('}')
	out.writeln('')

	for node in nodes {
		enum_name := to_enum_name(node.name)
		out.writeln('// as_${enum_name} returns this node as ${node.name}.')
		out.writeln('pub fn (node Node) as_${enum_name}() !${node.name} {')
		out.writeln('\tmatch node {')
		out.writeln('\t\t${node.name} { return node }')
		out.writeln("\t\telse { return error('expected ${node.name}, got \${node.base().kind}') }")
		out.writeln('\t}')
		out.writeln('}')
		out.writeln('')
	}

	content := out.str().trim_right('\n') + '\n'

	os.write_file(os.join_path('generated', 'node_methods.v'), content)!
	os.write_file(os.join_path('ast', 'node_methods.v'), content)!
}

// write_node_decoder writes canonical strong AST decoding from Prism node definitions.
fn write_node_decoder(nodes []NodeDef) ! {
	mut out := strings.new_builder(131072)

	out.writeln('// Code generated by tools/generate.v; DO NOT EDIT.')
	out.writeln('module serialize')
	out.writeln('')
	out.writeln('import vprism.ast')
	out.writeln('')
	out.writeln('// decode_node decodes a canonical strong Prism AST node.')
	out.writeln('pub fn decode_node(mut reader Reader, source string, pool ConstantPool) !ast.Node {')
	out.writeln('\tnode_type := reader.read_u8()!')
	out.writeln('\tnode_id := reader.read_varuint()!')
	out.writeln('\tlocation := reader.read_location()!')
	out.writeln('')
	out.writeln('\tmatch node_type {')

	for index, node in nodes {
		out.writeln('\t\t${index + 1} {')

		if node.name == 'DefNode' {
			out.writeln('\t\t\tserialized_length := reader.read_u32_le()!')
		} else {
			out.writeln('\t\t\tserialized_length := u32(0)')
		}

		out.writeln('\t\t\tflags := ast.NodeFlags(reader.read_varuint()!)')

		if node.fields.len > 0 {
			out.writeln('')
		}

		for field in node.fields {
			write_typed_field_decode(mut out, field)
		}

		if node.fields.len > 0 {
			out.writeln('')
		}

		out.writeln('\t\t\treturn ast.${node.name}{')
		out.writeln('\t\t\t\tbase: ast.NodeBase{')
		out.writeln('\t\t\t\t\tkind:              .${to_enum_name(node.name)}')
		out.writeln('\t\t\t\t\tid:                node_id')
		out.writeln('\t\t\t\t\tlocation:          location')
		out.writeln('\t\t\t\t\tflags:             flags')
		out.writeln('\t\t\t\t\tserialized_length: serialized_length')
		out.writeln('\t\t\t\t}')

		for field in node.fields {
			out.writeln('\t\t\t\t${field.v_name}: ${field.v_name}')
		}

		out.writeln('\t\t\t}')
		out.writeln('\t\t}')
	}

	out.writeln("\t\telse { return error('unknown Prism node type: \${node_type}') }")
	out.writeln('\t}')
	out.writeln('}')

	content := out.str()

	os.write_file(os.join_path('generated', 'node_decode.v'), content)!
	os.write_file(os.join_path('serialize', 'node_decode.v'), content)!
}

// write_typed_field_decode writes direct decoding statements for one AST field.
fn write_typed_field_decode(mut out strings.Builder, field FieldDef) {
	name := field.v_name

	match field.typ {
		'node' {
			out.writeln('\t\t\t${name} := decode_node(mut reader, source, pool)!')
		}
		'node?' {
			out.writeln('\t\t\tmut ${name} := ?ast.Node(none)')
			out.writeln('\t\t\tif reader.read_optional_node_prefix()! {')
			out.writeln('\t\t\t\t${name} = decode_node(mut reader, source, pool)!')
			out.writeln('\t\t\t}')
		}
		'node[]' {
			out.writeln('\t\t\t${name}_count := int(reader.read_varuint()!)')
			out.writeln('\t\t\tmut ${name} := []ast.Node{cap: ${name}_count}')
			out.writeln('\t\t\tfor _ in 0 .. ${name}_count {')
			out.writeln('\t\t\t\t${name} << decode_node(mut reader, source, pool)!')
			out.writeln('\t\t\t}')
		}
		'constant' {
			out.writeln('\t\t\t${name} := reader.read_constant_id()!')
		}
		'constant?' {
			out.writeln('\t\t\t${name}_raw := reader.read_optional_constant_id()!')
			out.writeln('\t\t\tmut ${name} := ?ast.ConstantId(none)')
			out.writeln('\t\t\tif ${name}_raw.has_value { ${name} = ${name}_raw.value }')
		}
		'constant[]' {
			out.writeln('\t\t\t${name}_count := int(reader.read_varuint()!)')
			out.writeln('\t\t\tmut ${name} := []ast.ConstantId{cap: ${name}_count}')
			out.writeln('\t\t\tfor _ in 0 .. ${name}_count {')
			out.writeln('\t\t\t\t${name} << reader.read_constant_id()!')
			out.writeln('\t\t\t}')
		}
		'string' {
			out.writeln('\t\t\t${name} := reader.read_prism_string(source)!')
		}
		'location' {
			out.writeln('\t\t\t${name} := reader.read_location()!')
		}
		'location?' {
			out.writeln('\t\t\t${name}_raw := reader.read_optional_location()!')
			out.writeln('\t\t\tmut ${name} := ?ast.Location(none)')
			out.writeln('\t\t\tif ${name}_raw.has_value { ${name} = ${name}_raw.value }')
		}
		'uint8' {
			out.writeln('\t\t\t${name} := reader.read_u8()!')
		}
		'uint32' {
			out.writeln('\t\t\t${name} := reader.read_uint32_field()!')
		}
		'integer' {
			out.writeln('\t\t\t${name} := reader.read_integer()!')
		}
		'double' {
			out.writeln('\t\t\t${name} := reader.read_double()!')
		}
		else {
			out.writeln("\t\t\treturn error('unsupported Prism field type ${field.typ}')")
		}
	}
}

// write_node_struct writes the V struct for a single Prism node definition.
fn write_node_struct(mut out strings.Builder, node NodeDef) {
	write_doc_comment(mut out, node.name, node.comment)

	out.writeln('pub struct ${node.name} {')
	out.writeln('pub:')
	out.writeln('\t// Base node metadata shared by all Prism AST nodes.')
	out.writeln('\tbase NodeBase')

	if node.fields.len > 0 {
		out.writeln('')
	}

	for i, field in node.fields {
		if i > 0 && should_separate_fields(node.fields[i - 1], field) {
			out.writeln('')
		}

		write_field_comment(mut out, field.comment)
		out.writeln('\t${field.v_name} ${field.v_type}')
	}

	out.writeln('}')
}

// should_separate_fields returns true when adjacent fields should be visually separated.
fn should_separate_fields(left FieldDef, right FieldDef) bool {
	return clean_comment(left.comment).len > 0 || clean_comment(right.comment).len > 0
}

// write_doc_comment writes a V doc comment for a generated declaration.
fn write_doc_comment(mut out strings.Builder, subject string, comment string) {
	cleaned := clean_comment(comment)

	if cleaned.len == 0 {
		out.writeln('// ${subject} is a Prism AST node.')
		return
	}

	lines := declaration_comment_lines(subject, cleaned)

	for line in lines {
		if line.trim_space() == '' {
			out.writeln('//')
		} else {
			out.writeln('// ${line}')
		}
	}
}

// declaration_comment_lines makes declaration comments start with their subject name.
fn declaration_comment_lines(subject string, comment string) []string {
	mut lines := comment.split('\n')

	if lines.len == 0 {
		return ['${subject} is a Prism AST node.']
	}

	first := lines[0].trim_space()

	if first.len == 0 {
		lines[0] = '${subject} is a Prism AST node.'
		return lines
	}

	if !first.starts_with(subject) {
		lines[0] = '${subject} ${lower_first(first)}'
	}

	return lines
}

// lower_first lowercases the first ASCII character in a comment sentence.
fn lower_first(text string) string {
	if text.len == 0 {
		return text
	}

	first := text[0]

	if first >= `A` && first <= `Z` {
		return '${u8(first + 32).ascii_str()}${text[1..]}'
	}

	return text
}

// write_field_comment writes a field comment when Prism provides one.
fn write_field_comment(mut out strings.Builder, comment string) {
	cleaned := clean_comment(comment)

	if cleaned.len == 0 {
		return
	}

	for line in cleaned.split('\n') {
		if line.trim_space() == '' {
			out.writeln('\t//')
		} else {
			out.writeln('\t// ${line}')
		}
	}
}

// clean_comment trims trailing whitespace while preserving Prism's examples.
fn clean_comment(comment string) string {
	mut lines := []string{}

	for line in comment.trim_space().split('\n') {
		lines << line.trim_right(' \t\r')
	}

	return lines.join('\n')
}
