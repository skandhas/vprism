# vprism

`vprism` is a V package for parsing Ruby source through
[Ruby Prism](https://github.com/ruby/prism) and rebuilding the serialized AST as
V data structures.

## Pre-release Status

`vprism` 0.1.0-pre.1 is a GitHub preview release. It is intended for early
testing and integration feedback before the stable 0.1.0 tag. Public APIs may
still change while the parser wrapper, serialized result models, generated AST,
and single-file analysis layer settle.

The public entry point parses Ruby source through Prism and returns a canonical,
strongly typed AST:

```v
import vprism

result := vprism.parse('puts "hello"')!
println(result.root)
```

Parser options use a V configuration struct:

```v
result := vprism.parse_with_options(source, vprism.ParseOptions{
	filepath: 'lib/example.rb'
	line: 10
	version: .ruby_3_4
})!

file_result := vprism.parse_file('lib/example.rb')!
```

Files can also be parsed through Prism's stream parser:

```v
stream_result := vprism.parse_stream_file('lib/example.rb')!
stream_analyzer := vprism.new_analyzer(stream_result)
```

Fast syntax checks use Prism's `pm_parse_success_p` without decoding the AST:

```v
if vprism.is_valid(source)! {
	println('valid Ruby')
}
```

Lexer APIs use Prism's `pm_serialize_lex` and `pm_serialize_parse_lex`:

```v
lexed := vprism.lex(source)!

for token in lexed.tokens {
	println('${token.kind}: ${lexed.text(token)!}')
}

parsed := vprism.parse_lex(source)!
println(parsed.parse.root)
```

Token kinds expose Prism's official token type names:

```v
for token in lexed.tokens {
	println('${token.kind.prism_name()}: ${lexed.text(token)!}')
}
```

Comment-only parsing uses Prism's `pm_serialize_parse_comments`:

```v
comments := vprism.parse_comments(source)!

for comment in comments.comments {
	println(comments.text(comment)!)
}
```

Locations can be converted to one-based lines and byte columns:

```v
position := result.position_at(node.base().location.start_offset)!
source_range := result.node_range(node)!
line := result.line_text(position.line)!
```

Prism diagnostics and node flags are exposed as typed V values:

```v
for diagnostic in result.metadata.errors {
	if diagnostic.kind == .err_def_name {
		println(diagnostic.error_level()!)
	}
}

call := result.find_first(.call)!.as_call()!

if call.has_flag(ast.call_node_safe_navigation) {
	println('safe navigation')
}
```

Query helpers are available on both the parse result and AST nodes:

```v
calls := result.find_all(.call)
first_def := result.find_first(.def)
```

Generated accessors expose each concrete node type:

```v
call_node := result.find_first(.call)!
call := call_node.as_call()!
println(result.constant_value(call.name)!)

if receiver := call.receiver {
	println(result.node_text(receiver)!)
}
```

Concrete node fields directly contain `ast.Node`, `?ast.Node`, and `[]ast.Node`
children. `AnalysisIndex` uses Prism node ids to resolve parents, ancestors, and
lexical scopes without converting between AST models.

Higher-level Ruby analysis is provided by `analysis.Analyzer`. Parse with the
root module, then construct analysis values through the root facade:

```v
parsed := vprism.parse(source)!
analyzer := vprism.new_analyzer(parsed)

for method in analyzer.methods() {
	println('${method.visibility} ${method.name}')

	for parameter in method.parameters {
		println('${parameter.kind}: ${parameter.name}')
	}

	for call in method.calls {
		println('calls: ${call.name}')
	}
}

for call in analyzer.calls() {
	println('${call.name}: ${call.arguments.len} arguments')

	if receiver := call.receiver {
		println('receiver: ${receiver.text}')
	}

	if block := call.block {
		println('block: ${block.kind}')
	}
}

for class_info in analyzer.classes() {
	println('${class_info.constant_path}: ${class_info.methods.len} methods')

	if superclass := class_info.superclass {
		println('superclass: ${superclass.text}')
	}
}

for module_info in analyzer.modules() {
	println('${module_info.constant_path}: ${module_info.nested_definitions.len} definitions')
}

for call in analyzer.calls() {
	for scope in analyzer.scope_path(call.node)! {
		println('${scope.kind}: ${scope.name}')
	}

	if method := analyzer.enclosing_method(call.node) {
		println('owned by method: ${method.name}')
	}
}

for constant in analyzer.constants() {
	println('${constant.usage}: ${constant.path}')
}

for variable in analyzer.variables() {
	println('${variable.kind} ${variable.usage}: ${variable.name}')
}

for dependency in analyzer.dependencies() {
	println('${dependency.kind}: ${dependency.path}')
}

for flow in analyzer.control_flows() {
	println('${flow.kind}: ${flow.text}')
}

for alias_info in analyzer.aliases() {
	println('${alias_info.new_name.name} -> ${alias_info.old_name.name}')
}

for region in analyzer.exception_regions() {
	println('${region.rescues.len} rescue clauses')
}

index := analyzer.analysis_index()

for call in analyzer.calls() {
	if parent := index.parent(call.node) {
		println('parent: ${parent.base().kind}')
	}
}
```

Prism debug output is available for JSON and pretty-printed ASTs:

```v
println(vprism.dump_json(source)!)
println(vprism.prettyprint(source)!)
```

Ruby name queries wrap Prism's string query APIs:

```v
println(vprism.is_local_name('value')!)
println(vprism.is_constant_name('Value')!)
println(vprism.is_method_name('[]=')!)
```

## Scope

`vprism` 0.1.0-pre.1 targets Ruby source parsing and single-file inspection. It
supports Prism 1.9.0 serialized AST decoding, strongly typed V AST nodes,
source locations, diagnostics, comments, lexing, debug output, token metadata,
Ruby name queries, and high-level structural analysis for one parsed source.

`vprism` does not evaluate Ruby code, run Ruby programs, infer global Ruby
types, resolve project-wide constants, load dependency graphs, or perform
cross-file semantic analysis. Those capabilities are intended for higher-level
packages or applications built on top of `vprism`.

## Design

- `ffi/` wraps the Prism C API.
- `serialize/` contains Prism serialized byte-stream result models and decoders.
- `ast/` contains the public AST model.
- `analysis/` contains optional high-level single-source structural analysis.
- `generated/` contains code generated from Prism's `config.yml`.
- `serialize/node_decode.v` contains the generated direct strong AST decoder.
- `serialize/lex.v` contains lexer and parse+lex result models and decoders.
- `tools/` contains maintainer tools, including the AST generator.

Generated files are committed so VPM users do not need to run the generator.

## Examples

```text
examples/parse_file.v
examples/parse_stream_file.v
examples/print_ast.v
examples/find_calls.v
examples/dump_json.v
examples/prettyprint.v
examples/query_names.v
```

## Maintainer Checks

Run the package checks before publishing:

```sh
v run tools/check.v
```

For a faster development check that skips `-prod test`:

```sh
v run tools/check.v --quick
```

## Prism Library

`vprism` vendors Prism's C headers and generated C sources under
`thirdparty/prism/include` and `thirdparty/prism/src`. The V package compiles
those C files together with the small shim in `ffi/prism_shim.c`, so the default
build does not require a separate native Prism library.

```text
thirdparty/prism/include
thirdparty/prism/src
```

The Prism sources in `thirdparty/prism/src` are expected to include Prism's
generated C files, such as `node.c`, `serialize.c`, `diagnostic.c`,
`token_type.c`, and `prettyprint.c`.

Native failures include the shim reason, such as buffer initialization failure
or allocation failure.
