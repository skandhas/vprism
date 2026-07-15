# Serialization

Prism serializes AST nodes into a byte stream. `vprism` decodes this stream and
rebuilds equivalent V structs.

The decoder is pinned to Prism serialization format `1.9.0`, the format used to
generate the checked-in AST, token, diagnostic, and flag types. Streams with a
different header version are rejected immediately.

## Reader primitives

`serialize.Reader` currently supports the primitive pieces needed before node
decoding:

- `u8`
- `varuint`
- `varsint`
- length-prefixed strings
- Prism string fields
- normal source locations
- optional source locations
- constant pool ids
- optional constant pool ids
- optional node prefixes
- fixed little-endian `u32` values
- `uint32` node fields encoded as `varuint`

For Prism 1.9.0, `node?` uses a single `0` byte for nil. If the byte is not
zero, it is the first node type byte and the reader rewinds before node decoding.
`location?` uses a `0` or `1` presence byte. `constant?` uses a serialized
varuint where `0` means nil and non-zero values are one-based constant pool
indexes.

## Decode boundary

`serialize.decode_parse` validates the fixed `PRISM` header, reads parser
metadata, decodes the strongly typed root node with access to the original Ruby source,
verifies that the node body ends at the constant-pool base, and decodes the
constant-pool trailer. `serialize.decode` is a convenience wrapper for callers
that do not have source context.

`serialize.decode_node` decodes directly into the public generated AST structs.
Its dispatch and field decoding code come from Prism's `config.yml`, so there is
no generic field container or second conversion pass.

`ast.Node` is a generated sum type passed by value, matching V's own AST style.
Generated `as_*` methods expose concrete structs, while `child_nodes`,
`find_first`, `find_all`, and `walk` operate over the complete typed tree.

## Constant Pool

The constant-pool table starts at the decoded `cpool_base` offset and contains
one 8-byte entry per constant. Each entry stores a little-endian offset and
little-endian length. When the offset has bit 31 set, the remaining offset bits
point into the serialized buffer and the bytes are owned by the serialized data.
Otherwise, the offset points into the original Ruby source.
