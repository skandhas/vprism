module tests

import os
import vprism
import vprism.ast
import vprism.serialize

struct VPrismValidCase {
	path  string
	kinds []ast.NodeKind
}

// test_vprism_version_matches_pre_release checks the package pre-release version.
fn test_vprism_version_matches_pre_release() {
	assert vprism.version == '0.1.0-pre.1'
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
