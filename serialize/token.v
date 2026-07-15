module serialize

import vprism.ffi

// token_kind_name returns Prism's official token type name for kind.
pub fn token_kind_name(kind TokenKind) string {
	return kind.prism_name()
}

// prism_name returns Prism's official token type name for kind.
pub fn (kind TokenKind) prism_name() string {
	if kind == .unknown {
		return 'UNKNOWN'
	}

	return ffi.token_type_name(int(kind))
}
