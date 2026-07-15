# Compatibility

`vprism` is pinned to Prism serialization format `1.9.0`.

Serialized streams with a different header version are rejected before metadata,
token, comment, or AST decoding begins. This keeps the generated V AST,
diagnostics, token kinds, and node flags aligned with the bundled
`thirdparty/prism/config.yml`.

The bundled Prism C headers and sources under `thirdparty/prism/include` and
`thirdparty/prism/src` should be updated together with `config.yml` and the
generated V files.
