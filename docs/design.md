# Design

`vprism` has four layers:

1. A small C FFI layer around Prism.
2. A binary decoder for `pm_serialize_parse` output.
3. A V AST model generated from Prism's `config.yml`.
4. An optional high-level structural analysis module.

The `serialize` module owns the Prism binary protocol, parser metadata,
constant pool, parse result, lexer result, token kind model, and decoders. The
root module exposes convenience facades and public type names for common result
types. The `analysis` module depends on `serialize` and `ast` and exposes
`Analyzer`; it does not perform project-wide resolution or Ruby type inference.

The public AST types live in the `vprism.ast` submodule. Local development uses
`.vmodules/vprism` as a junction back to the project root, matching how VPM users
will import the package after installation.

The runtime package should not require users to run the generator.
