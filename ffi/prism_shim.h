#ifndef VPRISM_PRISM_SHIM_H
#define VPRISM_PRISM_SHIM_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    uint8_t *data;
    size_t len;
} vprism_serialized_buffer_t;

bool vprism_serialize_parse(const char *source, size_t source_len, vprism_serialized_buffer_t *out);
bool vprism_serialize_parse_with_options(const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out);
bool vprism_serialize_parse_stream_file(const char *path, const char *options, vprism_serialized_buffer_t *out);
bool vprism_serialize_parse_comments(const char *source, size_t source_len, vprism_serialized_buffer_t *out);
bool vprism_serialize_parse_comments_with_options(const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out);
bool vprism_serialize_lex(const char *source, size_t source_len, vprism_serialized_buffer_t *out);
bool vprism_serialize_lex_with_options(const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out);
bool vprism_serialize_parse_lex(const char *source, size_t source_len, vprism_serialized_buffer_t *out);
bool vprism_serialize_parse_lex_with_options(const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out);
bool vprism_parse_success(const char *source, size_t source_len, bool *out_success);
bool vprism_parse_success_with_options(const char *source, size_t source_len, const char *options, bool *out_success);
bool vprism_dump_json(const char *source, size_t source_len, vprism_serialized_buffer_t *out);
bool vprism_dump_json_with_options(const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out);
bool vprism_prettyprint(const char *source, size_t source_len, vprism_serialized_buffer_t *out);
bool vprism_prettyprint_with_options(const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out);
int vprism_string_query_local(const char *source, size_t source_len, const char *encoding_name);
int vprism_string_query_constant(const char *source, size_t source_len, const char *encoding_name);
int vprism_string_query_method_name(const char *source, size_t source_len, const char *encoding_name);
const char *vprism_token_type_name(int token_type);
const char *vprism_version(void);
const char *vprism_last_error(void);
void vprism_serialized_buffer_free(vprism_serialized_buffer_t *buffer);

#endif
