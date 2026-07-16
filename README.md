# vprism

`vprism` parses Ruby source through [Ruby Prism](https://github.com/ruby/prism)
and decodes Prism's serialized AST into V data structures.

It vendors Prism's C sources, so the default V build compiles Prism together
with the package. No separate Prism shared library is required.

## Pre-release Status

`vprism` 0.1.0-pre.1 is a GitHub preview release for early testing and
integration feedback before the stable 0.1.0 tag.

Public APIs may still change while the parser wrapper, serialized result
models, generated AST, and single-file analysis layer settle.

## Quick Start

```v
import vprism

result := vprism.parse('puts "hello"')!

println(result.root.base().kind)
println(result.root)
```

Parse a Ruby file:

```v
result := vprism.parse_file('lib/example.rb')!

for diagnostic in result.metadata.errors {
	println('${diagnostic.kind}: ${diagnostic.message}')
}
```

Use parser options:

```v
result := vprism.parse_with_options(source, vprism.ParseOptions{
	filepath: 'lib/example.rb'
	line: 10
	encoding: 'UTF-8'
	version: .ruby_3_4
})!
```

## Core APIs

### Parsing

`parse` and `parse_file` call Prism's serialized parse API and decode the
returned byte stream into `vprism.ParseResult`.

```v
result := vprism.parse(source)!
file_result := vprism.parse_file('lib/example.rb')!
```

Files can also be parsed through Prism's stream parser:

```v
stream_result := vprism.parse_stream_file('lib/example.rb')!
```

Fast syntax checks use Prism's parse-success API without decoding the AST:

```v
if vprism.is_valid(source)! {
	println('valid Ruby')
}
```

### AST Access

`ParseResult.root` is a strongly typed `ast.Node` sum type. Use `find_first`,
`find_all`, and generated `as_*` accessors to work with concrete nodes.

```v
call_node := result.find_first(.call) or { return }
call := call_node.as_call()!

println(result.constant_value(call.name)!)

if receiver := call.receiver {
	println(result.node_text(receiver)!)
}
```

AST nodes keep Prism source locations. `ParseResult` provides source text,
line, and range helpers:

```v
text := result.node_text(call_node)!
position := result.position_at(call_node.base().location.start_offset)!
source_range := result.node_range(call_node)!
line := result.line_text(position.line)!

println('${source_range.start.line}:${source_range.start.column} ${text}')
```

### Walking

Implement `ast.Visitor` to walk every node. The visitor receives `&ast.Node`,
which avoids copying the sum type during traversal.

```v
import vprism.ast

struct Counter {
mut:
	count int
}

fn (mut counter Counter) visit(node &ast.Node) ! {
	counter.count++
	node.base()
}

mut counter := Counter{}
result.walk(mut counter)!
println(counter.count)
```

### Lexing

Lexer APIs use Prism's serialized lexer APIs and return token locations tied to
the original source.

```v
lexed := vprism.lex(source)!

for token in lexed.tokens {
	println('${token.kind.prism_name()}: ${lexed.text(token)!}')
}
```

`parse_lex` returns both the decoded AST and tokens from the same Prism run:

```v
parsed := vprism.parse_lex(source)!

println(parsed.parse.root.base().kind)
println(parsed.tokens.len)
```

### Comments

Comment-only parsing uses Prism's `pm_serialize_parse_comments` API.

```v
comments := vprism.parse_comments(source)!

for comment in comments.comments {
	println(comments.text(comment)!)
}
```

File and options variants are also available:

```v
comments := vprism.parse_comments_file('lib/example.rb')!
comments_with_options := vprism.parse_comments_with_options(source, vprism.ParseOptions{
	line: 20
})!
```

Full parse results also include comments, magic comments, and `__END__`
metadata:

```v
for magic in result.metadata.magic_comments {
	println(result.source_text(magic.key_loc)!)
	println(result.source_text(magic.value_loc)!)
}
```

### Diagnostics

Parser diagnostics are decoded into typed values.

```v
for diagnostic in result.metadata.errors {
	if diagnostic.is_error() {
		println('${diagnostic.error_level()!}: ${diagnostic.message}')
	}
}

for warning in result.metadata.warnings {
	if warning.is_warning() {
		println('${warning.warning_level()!}: ${warning.message}')
	}
}
```

### Debug Output

Prism debug output is exposed for JSON and pretty-printed ASTs.

```v
println(vprism.dump_json(source)!)
println(vprism.prettyprint(source)!)

println(vprism.dump_json_file('lib/example.rb')!)
println(vprism.prettyprint_file('lib/example.rb')!)
```

### Ruby Name Queries

Ruby name queries wrap Prism's string query APIs.

```v
println(vprism.is_local_name('value')!)
println(vprism.is_constant_name('Value')!)
println(vprism.is_method_name('[]=')!)
```

## Single-file Analysis

`analysis.Analyzer` provides higher-level structural information for one parsed
source. Construct it through the root facade:

```v
parsed := vprism.parse(source)!
analyzer := vprism.new_analyzer(parsed)
```

Inspect methods, calls, classes, and modules:

```v
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
}

for module_info in analyzer.modules() {
	println('${module_info.constant_path}: ${module_info.nested_definitions.len} definitions')
}
```

Inspect constants, variables, dependencies, aliases, control flow, and exception
regions:

```v
for constant in analyzer.constants() {
	println('${constant.usage}: ${constant.path}')
}

for variable in analyzer.variables() {
	println('${variable.kind} ${variable.usage}: ${variable.name}')
}

for dependency in analyzer.dependencies() {
	println('${dependency.kind}: ${dependency.path}')
}

for alias_info in analyzer.aliases() {
	println('${alias_info.new_name.name} -> ${alias_info.old_name.name}')
}

for flow in analyzer.control_flows() {
	println('${flow.kind}: ${flow.text}')
}

for region in analyzer.exception_regions() {
	println('${region.rescues.len} rescue clauses')
}
```

Resolve lexical scope and AST parent information:

```v
for call in analyzer.calls() {
	for scope in analyzer.scope_path(call.node)! {
		println('${scope.kind}: ${scope.name}')
	}

	if method := analyzer.enclosing_method(call.node) {
		println('owned by method: ${method.name}')
	}
}

index := analyzer.analysis_index()

for call in analyzer.calls() {
	if parent := index.parent(call.node) {
		println('parent: ${parent.base().kind}')
	}
}
```

## Scope

`vprism` 0.1.0-pre.1 targets Ruby source parsing and single-file inspection.

It currently provides:

- Prism 1.9.0 C integration.
- Serialized AST decoding into V data structures.
- Strongly typed generated AST nodes.
- Source text, line, and range helpers.
- Parser diagnostics, comments, magic comments, and `__END__` metadata.
- Lexing and parse+lex APIs.
- Prism JSON and prettyprint debug output.
- Ruby local, constant, and method name queries.
- High-level structural analysis for one parsed source.

It does not:

- Evaluate Ruby code.
- Run Ruby programs.
- Infer global Ruby types.
- Resolve project-wide constants.
- Build cross-file dependency graphs.
- Perform project-level semantic analysis.

Those capabilities are intended for higher-level packages or applications built
on top of `vprism`.

## Examples

Example programs live in `examples/`:

```text
examples/print_ast.v
examples/parse_file.v
examples/parse_stream_file.v
examples/find_calls.v
examples/dump_json.v
examples/prettyprint.v
examples/query_names.v
```

Run an example from the package root:

```sh
v run examples/print_ast.v
v run examples/find_calls.v path/to/file.rb
v run examples/dump_json.v path/to/file.rb
```

Compile an example:

```sh
v -o examples/dump_json.exe examples/dump_json.v
```

When using an unpublished checkout, make sure V can resolve the module. One
simple local development option is to set `VMODULES` to this package's
`.vmodules` directory:

```sh
VMODULES="$(pwd)/.vmodules" v run examples/print_ast.v
```

On Windows `cmd.exe`:

```bat
set VMODULES=%CD%\.vmodules
v run examples\print_ast.v
```

On PowerShell:

```powershell
$env:VMODULES=(Resolve-Path .vmodules).Path
v run examples\print_ast.v
```

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

`vprism` vendors Prism's C headers and generated C sources under:

```text
thirdparty/prism/include
thirdparty/prism/src
```

The V package compiles those C files together with the small shim in
`ffi/prism_shim.c`. The C source list is declared in `ffi/prism.v` through V
`#flag` directives.

The Prism sources in `thirdparty/prism/src` are expected to include Prism's
generated C files, such as `node.c`, `serialize.c`, `diagnostic.c`,
`token_type.c`, and `prettyprint.c`.

Native failures include the shim reason, such as buffer initialization failure
or allocation failure.
