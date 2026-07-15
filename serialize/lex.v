module serialize

import vprism.ast

// Token describes one Ruby lexer token returned by Prism.
pub struct Token {
pub:
	// kind is the Prism token kind.
	kind TokenKind

	// location points to the token bytes in the original source.
	location ast.Location

	// lex_state is Prism's lexer state after this token was read.
	lex_state u32
}

// LexResult contains Prism lexer tokens and parser metadata.
pub struct LexResult {
pub:
	// source is the original Ruby source used for token text lookups.
	source string

	// tokens contains lexer tokens in source order.
	tokens []Token

	// metadata contains parser metadata produced while lexing.
	metadata Metadata
}

// ParseLexResult contains both lexer tokens and the decoded AST from Prism.
pub struct ParseLexResult {
pub:
	// source is the original Ruby source used for token and AST lookups.
	source string

	// tokens contains lexer tokens in source order.
	tokens []Token

	// parse contains the decoded serialized AST result.
	parse ParseResult
}

// text returns the source text covered by this token.
pub fn (result LexResult) text(token Token) !string {
	return source_slice(result.source, token.location)
}

// text returns the source text covered by this token.
pub fn (result ParseLexResult) text(token Token) !string {
	return source_slice(result.source, token.location)
}

// decode_lex decodes Prism serialized lexer bytes.
pub fn decode_lex(source string, data []u8) !LexResult {
	mut reader := new_reader(data)
	tokens := read_serialized_tokens(mut reader)!
	metadata := read_metadata(mut reader)!

	if reader.remaining() != 0 {
		return error('serialized lex result has trailing bytes')
	}

	return LexResult{
		source:   source
		tokens:   tokens
		metadata: metadata
	}
}

// decode_parse_lex decodes Prism serialized tokens followed by a serialized AST.
pub fn decode_parse_lex(source string, data []u8) !ParseLexResult {
	mut reader := new_reader(data)
	tokens := read_serialized_tokens(mut reader)!
	parse := decode_parse_at(source, data, reader.position())!

	return ParseLexResult{
		source: source
		tokens: tokens
		parse:  parse
	}
}

// read_serialized_tokens decodes the token prefix shared by lex and parse_lex.
pub fn read_serialized_tokens(mut reader Reader) ![]Token {
	mut tokens := []Token{}

	for {
		raw_kind := reader.read_varuint()!

		if raw_kind == 0 {
			break
		}

		start_offset := reader.read_varuint()!
		length := reader.read_varuint()!
		lex_state := reader.read_varuint()!

		tokens << Token{
			kind:      token_kind_from_value(raw_kind)!
			location:  ast.Location{
				start_offset: start_offset
				length:       length
			}
			lex_state: lex_state
		}
	}

	return tokens
}

// source_slice returns the source substring covered by a location.
pub fn source_slice(source string, location ast.Location) !string {
	start := int(location.start_offset)
	length := int(location.length)

	if start < 0 || length < 0 || start + length > source.len {
		return error('location is outside the source bounds')
	}

	return source.bytes()[start..start + length].bytestr()
}
