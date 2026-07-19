module tests

import os
import vprism
import vprism.analysis
import vprism.ast
import vprism.serialize

struct VPrismValidCase {
	path  string
	kinds []ast.NodeKind
}

// test_vprism_version_matches_release checks the package release version.
fn test_vprism_version_matches_release() {
	assert vprism.version == '0.1.0'
}

// fixture_path returns the path to a vprism-owned fixture.
fn fixture_path(parts ...string) string {
	mut path := os.join_path(os.dir(@FILE), 'fixtures', 'vprism')

	for part in parts {
		path = os.join_path(path, part)
	}

	return path
}

// read_fixture reads a vprism-owned fixture.
fn read_fixture(parts ...string) string {
	return os.read_file(fixture_path(...parts)) or {
		panic('failed to read vprism fixture ${parts.join('/')}: ${err}')
	}
}

// accept_parse_result checks that the root parse result facade type is usable by callers.
fn accept_parse_result(result vprism.ParseResult) {
	assert result.root.base().kind == .program
}

// accept_lex_result checks that the root lex result facade type is usable by callers.
fn accept_lex_result(result vprism.LexResult) {
	assert result.tokens.len > 0
}

// accept_parse_lex_result checks that the root parse+lex result facade type is usable by callers.
fn accept_parse_lex_result(result vprism.ParseLexResult) {
	assert result.parse.root.base().kind == .program
	assert result.tokens.len > 0
}

// accept_token_kind checks that the root token kind facade type is usable by callers.
fn accept_token_kind(kind vprism.TokenKind) {
	assert vprism.token_kind_name(kind).len > 0
}

// test_vprism_valid_fixtures_decode_and_walk checks owned valid fixtures through the parse facade.
fn test_vprism_valid_fixtures_decode_and_walk() {
	cases := [
		VPrismValidCase{
			path:  'basic.rb'
			kinds: [.local_variable_write, .call]
		},
		VPrismValidCase{
			path:  'class_method.rb'
			kinds: [.module_, .class, .def, .instance_variable_write]
		},
		VPrismValidCase{
			path:  'pattern_matching.rb'
			kinds: [.case_match, .hash_pattern, .local_variable_target]
		},
	]

	for fixture in cases {
		source := read_fixture('valid', fixture.path)
		result := vprism.parse(source)!

		accept_parse_result(result)

		assert result.source == source
		assert result.metadata.errors.len == 0
		assert result.root.base().kind == .program
		assert result.node_text(result.root)!.len > 0

		mut counter := VPrismNodeCounter{}
		result.walk(mut counter)!
		assert counter.count > 0

		for kind in fixture.kinds {
			assert result.find_all(kind).len > 0
		}
	}
}

// test_vprism_parse_file_and_stream_file_facades checks file-based parsing facades.
fn test_vprism_parse_file_and_stream_file_facades() {
	path := fixture_path('valid', 'basic.rb')
	source := read_fixture('valid', 'basic.rb')
	parsed := vprism.parse_file(path)!
	streamed := vprism.parse_stream_file(path)!

	assert vprism.is_valid_file(path)!
	assert parsed.source == source
	assert streamed.source == source
	assert parsed.metadata.errors.len == 0
	assert streamed.metadata.errors.len == 0
	assert parsed.root.base().kind == streamed.root.base().kind
	assert parsed.node_text(parsed.root)! == streamed.node_text(streamed.root)!
}

// test_vprism_parse_options_validate_and_affect_metadata checks public parse options.
fn test_vprism_parse_options_validate_and_affect_metadata() {
	source := read_fixture('valid', 'basic.rb')
	result := vprism.parse_with_options(source, vprism.ParseOptions{
		filepath: 'owned/basic.rb'
		line:     42
		encoding: 'UTF-8'
		version:  .ruby_3_3
	})!

	assert result.metadata.start_line == 42
	assert result.metadata.encoding == 'UTF-8'
	assert vprism.is_valid_with_options(source, vprism.ParseOptions{
		line:    42
		version: .ruby_3_4
	})!

	if _ := vprism.parse_with_options(source, vprism.ParseOptions{
		line: 0
	})
	{
		assert false
	} else {
		assert err.msg().contains('line')
	}

	if _ := vprism.is_valid_with_options(source, vprism.ParseOptions{
		command_line: 'z'
	})
	{
		assert false
	} else {
		assert err.msg().contains('unsupported command-line')
	}
}

// test_vprism_invalid_fixture_reports_diagnostics checks diagnostic decoding for owned invalid source.
fn test_vprism_invalid_fixture_reports_diagnostics() {
	source := read_fixture('invalid', 'unterminated_def.rb')
	result := vprism.parse(source)!

	assert result.root.base().kind == .program
	assert result.metadata.errors.len > 0

	first := result.metadata.errors[0]
	assert first.is_error()
	assert first.error_level()! == .syntax
	assert first.message.len > 0
	assert first.location.start_offset <= u32(source.len)
	assert first.location.length <= u32(source.len)
}

// test_vprism_debug_and_query_facades checks Prism debug dumps and string query wrappers.
fn test_vprism_debug_and_query_facades() {
	source := read_fixture('valid', 'basic.rb')
	path := fixture_path('valid', 'basic.rb')
	json := vprism.dump_json(source)!
	json_with_options := vprism.dump_json_with_options(source, vprism.ParseOptions{
		line: 7
	})!
	file_json := vprism.dump_json_file(path)!
	pretty := vprism.prettyprint(source)!
	file_pretty := vprism.prettyprint_file(path)!

	assert vprism.prism_version().len > 0
	assert json.starts_with('{')
	assert json.contains('ProgramNode')
	assert json_with_options.contains('ProgramNode')
	assert file_json.contains('ProgramNode')
	assert pretty.contains('ProgramNode')
	assert file_pretty.contains('ProgramNode')

	assert vprism.is_local_name('local_name')!
	assert !vprism.is_local_name('User')!
	assert vprism.is_constant_name('User')!
	assert !vprism.is_constant_name('local_name')!
	assert vprism.is_method_name('active?')!
	assert vprism.is_method_name('[]=')!
}

// test_vprism_lex_fixture_checks_token_locations checks lex and parse+lex owned fixtures.
fn test_vprism_lex_fixture_checks_token_locations() {
	source := read_fixture('lex', 'operators.rb')
	lexed := vprism.lex(source)!
	parsed := vprism.parse_lex(source)!

	accept_lex_result(lexed)
	accept_parse_lex_result(parsed)
	accept_token_kind(.identifier)

	assert lexed.source == source
	assert parsed.source == source
	assert parsed.parse.metadata.errors.len == 0
	assert lexed.tokens.len == parsed.tokens.len
	assert lexed.tokens.last().kind == .eof
	assert parsed.tokens.last().kind == .eof
	assert lexed.tokens.any(it.kind == .ampersand_dot && lexed.text(it)! == '&.')
	assert lexed.tokens.any(it.kind in [.star_star, .ustar_star] && lexed.text(it)! == '**')
	assert lexed.tokens.any(it.kind == .pipe_pipe_equal && lexed.text(it)! == '||=')

	for index, token in lexed.tokens {
		parsed_token := parsed.tokens[index]

		assert token.kind == parsed_token.kind
		assert token.location.start_offset == parsed_token.location.start_offset
		assert token.location.length == parsed_token.location.length

		end_offset := u64(token.location.start_offset) + u64(token.location.length)
		assert end_offset <= u64(source.len)
		lexed.text(token)!
	}
}

// test_vprism_comments_fixture_checks_comments_and_magic_comments checks comments APIs.
fn test_vprism_comments_fixture_checks_comments_and_magic_comments() {
	source := read_fixture('comments', 'magic_and_inline.rb')
	comments := vprism.parse_comments(source)!
	parsed := vprism.parse(source)!

	assert comments.source == source
	assert comments.comments.len >= 4
	assert comments.text(comments.comments[0])! == '# frozen_string_literal: true'
	assert comments.text(comments.comments[1])! == '# typed: strict'
	assert comments.comments.any(it.kind == serialize.CommentKind.embdoc)
	assert comments.comments.any(comments.text(it)! == '# inline value')
	assert parsed.metadata.magic_comments.len == 2
	assert parsed.metadata.comments.len == comments.comments.len

	assert parsed.metadata.data_loc.has_value
	assert parsed.source_text(parsed.metadata.data_loc.value)!.starts_with('__END__')
}

// test_vprism_comments_file_and_options_facades checks comments-only public facades.
fn test_vprism_comments_file_and_options_facades() {
	source := read_fixture('comments', 'magic_and_inline.rb')
	path := fixture_path('comments', 'magic_and_inline.rb')
	comments := vprism.parse_comments_with_options(source, vprism.ParseOptions{
		line: 20
	})!
	file_comments := vprism.parse_comments_file(path)!

	assert comments.source == source
	assert comments.start_line == 20
	assert comments.encoding == 'UTF-8'
	assert comments.comments.len == file_comments.comments.len
	assert file_comments.source == source
	assert file_comments.text(file_comments.comments[0])! == '# frozen_string_literal: true'
}

// test_vprism_analysis_structure_fixture_checks_high_level_api checks structural analysis APIs.
fn test_vprism_analysis_structure_fixture_checks_high_level_api() {
	source := read_fixture('analysis', 'structure.rb')
	parsed := vprism.parse(source)!
	analyzer := vprism.new_analyzer(parsed)
	modules := analyzer.modules()
	classes := analyzer.classes()
	methods := analyzer.methods()
	dependencies := analyzer.dependencies()
	constants := analyzer.constants()
	variables := analyzer.variables()
	aliases := analyzer.aliases()
	undefs := analyzer.undefs()

	assert modules.any(it.name == 'App' && it.constant_path == 'App')
	assert classes.any(it.name == 'User')
	assert methods.any(it.name == 'initialize')
	assert methods.any(it.name == 'token')
	assert dependencies.any(it.kind == .require_ && it.path == 'json' && !it.dynamic)
	assert dependencies.any(it.kind == .require_relative && it.path == 'support/user' && !it.dynamic)
	assert dependencies.any(it.kind == .load && it.dynamic)
	assert dependencies.any(it.kind == .autoload && it.constant_name == 'Worker'
		&& it.path == 'app/worker')
	assert constants.any(it.name == 'ROLE' && it.usage == .write)
	assert constants.any(it.name == 'App' && it.usage == .declaration)
	assert variables.any(it.name == '@name' && it.kind == .instance && it.usage == .write)
	assert variables.any(it.name == '@active' && it.kind == .instance && it.usage == .write)
	assert aliases.any(it.kind == .method && it.new_name.name == 'new_token'
		&& it.old_name.name == 'token')
	assert undefs.any(it.names.any(it.name == 'old_token'))

	user_class := classes.filter(it.name == 'User')[0]
	assert user_class.superclass != none
	assert user_class.methods.any(it.name == 'initialize' && it.parameters.len >= 4)
	assert user_class.methods.any(it.name == 'token'
		&& it.visibility == analysis.MethodVisibility.private_)

	return_node := parsed.find_first(.return_) or {
		assert false
		return
	}
	scopes := analyzer.scope_path(return_node)!

	assert scopes.any(it.kind == .module_ && it.name == 'App')
	assert scopes.any(it.kind == .class_ && it.name == 'User')
	assert scopes.any(it.kind == .method && it.name == 'token')

	if owner_class := analyzer.enclosing_class(return_node) {
		assert owner_class.name == 'User'
	} else {
		assert false
	}

	if owner_module := analyzer.enclosing_module(return_node) {
		assert owner_module.name == 'App'
	} else {
		assert false
	}

	if owner_method := analyzer.enclosing_method(return_node) {
		assert owner_method.name == 'token'
	} else {
		assert false
	}
}

// test_vprism_analysis_control_exception_fixture_checks_flow_api checks flow and exception APIs.
fn test_vprism_analysis_control_exception_fixture_checks_flow_api() {
	source := read_fixture('analysis', 'control_exception.rb')
	analyzer := analysis.Analyzer.new(vprism.parse(source)!)
	flows := analyzer.control_flows()
	methods := analyzer.methods()
	regions := analyzer.exception_regions()
	rescues := analyzer.rescues()

	assert flows.any(it.kind == .next_)
	assert flows.any(it.kind == .break_)
	assert flows.any(it.kind == .yield_)
	assert flows.any(it.kind == .return_)
	assert flows.any(it.kind == .super_)
	assert methods.any(it.name == 'flow' && it.control_flows.any(it.kind == .return_))
	assert regions.len == 1
	assert regions[0].rescues.len == 1
	assert regions[0].else_body != none
	assert regions[0].ensure_body != none
	assert rescues.any(it.modifier)
	assert rescues.any(!it.modifier && it.exceptions.len == 1 && it.reference != none)
}

// test_vprism_source_fixture_checks_utf8_and_start_line_mapping checks source mapping helpers.
fn test_vprism_source_fixture_checks_utf8_and_start_line_mapping() {
	source := read_fixture('source', 'utf8_lines.rb')
	result := vprism.parse_with_options(source, vprism.ParseOptions{
		line: 10
	})!
	value_offset := u32(source.index('value') or { panic('missing value marker') })
	utf8_offset := source.index('茅') or { panic('missing utf8 marker') }
	utf8_end := u32(utf8_offset + '茅'.len)
	value_node := result.find_first(.local_variable_write) or {
		assert false
		return
	}

	assert result.metadata.start_line == 10
	assert result.position_at(value_offset)!.line == 11
	assert result.position_at(value_offset)!.column == 1
	assert result.position_at(utf8_end)!.column == 10
	assert result.line_text(10)! == 'puts "茅"'
	assert result.line_text(11)! == 'value = 1'
	assert result.node_range(value_node)!.start.line == 11
}

struct VPrismNodeCounter {
mut:
	count int
}

// visit counts every node visited by the vprism-owned fixture walker.
fn (mut counter VPrismNodeCounter) visit(node &ast.Node) ! {
	counter.count++
	node.base()
}
