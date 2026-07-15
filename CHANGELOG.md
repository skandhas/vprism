# Changelog

## 0.1.0-pre.1

- Initial pre-release for GitHub preview use.
- Parse Ruby source through the vendored Ruby Prism 1.9.0 C API.
- Decode Prism serialized AST bytes into a strongly typed V AST.
- Expose parse, stream parse, syntax check, lex, parse+lex, comments, debug, token, and Ruby name query APIs.
- Provide source locations, diagnostics, constant pool access, node traversal, node search, and generated typed node accessors.
- Provide single-source structural analysis for methods, classes, modules, calls, constants, variables, dependencies, control flow, aliases, undef, rescue, ensure, and lexical scope queries.
- Marked as pre-release; public APIs may still change before 0.1.0.
