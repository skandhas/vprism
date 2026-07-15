module vprism

import vprism.serialize

// TokenKind identifies a Prism lexer token kind.
pub type TokenKind = serialize.TokenKind

// token_kind_name returns Prism's official token type name for kind.
pub fn token_kind_name(kind TokenKind) string {
	return serialize.token_kind_name(serialize.TokenKind(kind))
}
