#include "prism_shim.h"

#include "prism.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void (*pm_serialize_parse_fn)(pm_buffer_t *buffer, const uint8_t *source, size_t size, const char *data);
typedef void (*vprism_render_node_fn)(pm_buffer_t *buffer, const pm_parser_t *parser, const pm_node_t *node);
static char vprism_error[512] = { 0 };

static char *
vprism_file_fgets(char *string, int size, void *stream) {
    return fgets(string, size, (FILE *) stream);
}

static int
vprism_file_feof(void *stream) {
    return feof((FILE *) stream);
}

static void
vprism_clear_error(void) {
    vprism_error[0] = '\0';
}

static void
vprism_set_error(const char *message) {
    if (message == NULL) {
        vprism_error[0] = '\0';
        return;
    }

    snprintf(vprism_error, sizeof(vprism_error), "%s", message);
}

const char *
vprism_last_error(void) {
    return vprism_error;
}

static bool
vprism_copy_buffer(pm_buffer_t *buffer, vprism_serialized_buffer_t *out) {
    if (out == NULL) {
        vprism_set_error("serialized buffer output pointer is null");
        return false;
    }

    out->data = NULL;
    out->len = 0;

    size_t len = pm_buffer_length(buffer);
    uint8_t *data = (uint8_t *) malloc(len == 0 ? 1 : len);
    if (data == NULL) {
        vprism_set_error("Prism serialized buffer allocation failed");
        return false;
    }

    if (len > 0) {
        memcpy(data, pm_buffer_value(buffer), len);
    }

    out->data = data;
    out->len = len;
    vprism_clear_error();

    return true;
}

static bool
vprism_serialize_to_buffer(pm_serialize_parse_fn serialize, const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out) {
    if (out == NULL) {
        vprism_set_error("serialized buffer output pointer is null");
        return false;
    }

    out->data = NULL;
    out->len = 0;

    if (serialize == NULL) {
        vprism_set_error("Prism serializer function pointer is null");
        return false;
    }

    pm_buffer_t buffer;
    if (!pm_buffer_init(&buffer)) {
        vprism_set_error("Prism buffer initialization failed");
        return false;
    }

    serialize(&buffer, (const uint8_t *) source, source_len, options);
    bool result = vprism_copy_buffer(&buffer, out);

    pm_buffer_free(&buffer);

    return result;
}

static bool
vprism_render_parse(vprism_render_node_fn render, const char *source, size_t source_len, const char *options_data, vprism_serialized_buffer_t *out) {
    if (out == NULL) {
        vprism_set_error("serialized buffer output pointer is null");
        return false;
    }

    out->data = NULL;
    out->len = 0;

    if (render == NULL) {
        vprism_set_error("Prism render function pointer is null");
        return false;
    }

    pm_options_t options = { 0 };
    pm_options_read(&options, options_data);

    pm_parser_t parser;
    pm_parser_init(&parser, (const uint8_t *) source, source_len, &options);

    pm_node_t *node = pm_parse(&parser);

    pm_buffer_t buffer;
    if (!pm_buffer_init(&buffer)) {
        pm_node_destroy(&parser, node);
        pm_parser_free(&parser);
        pm_options_free(&options);
        vprism_set_error("Prism buffer initialization failed");
        return false;
    }

    render(&buffer, &parser, node);
    bool result = vprism_copy_buffer(&buffer, out);

    pm_buffer_free(&buffer);
    pm_node_destroy(&parser, node);
    pm_parser_free(&parser);
    pm_options_free(&options);

    return result;
}

bool
vprism_serialize_parse(const char *source, size_t source_len, vprism_serialized_buffer_t *out) {
    return vprism_serialize_parse_with_options(source, source_len, NULL, out);
}

bool
vprism_serialize_parse_comments(const char *source, size_t source_len, vprism_serialized_buffer_t *out) {
    return vprism_serialize_parse_comments_with_options(source, source_len, NULL, out);
}

bool
vprism_serialize_parse_stream_file(const char *path, const char *options, vprism_serialized_buffer_t *out) {
    if (out == NULL) {
        vprism_set_error("serialized buffer output pointer is null");
        return false;
    }

    out->data = NULL;
    out->len = 0;

    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        snprintf(vprism_error, sizeof(vprism_error), "failed to open Ruby source stream: %s", path);
        return false;
    }

    pm_buffer_t buffer;
    if (!pm_buffer_init(&buffer)) {
        fclose(file);
        vprism_set_error("Prism buffer initialization failed");
        return false;
    }

    pm_serialize_parse_stream(&buffer, file, vprism_file_fgets, vprism_file_feof, options);
    bool result = vprism_copy_buffer(&buffer, out);

    pm_buffer_free(&buffer);
    fclose(file);

    return result;
}

bool
vprism_serialize_parse_comments_with_options(const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out) {
    return vprism_serialize_to_buffer(pm_serialize_parse_comments, source, source_len, options, out);
}

bool
vprism_serialize_lex(const char *source, size_t source_len, vprism_serialized_buffer_t *out) {
    return vprism_serialize_lex_with_options(source, source_len, NULL, out);
}

bool
vprism_serialize_lex_with_options(const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out) {
    return vprism_serialize_to_buffer(pm_serialize_lex, source, source_len, options, out);
}

bool
vprism_serialize_parse_lex(const char *source, size_t source_len, vprism_serialized_buffer_t *out) {
    return vprism_serialize_parse_lex_with_options(source, source_len, NULL, out);
}

bool
vprism_serialize_parse_lex_with_options(const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out) {
    return vprism_serialize_to_buffer(pm_serialize_parse_lex, source, source_len, options, out);
}

bool
vprism_parse_success(const char *source, size_t source_len, bool *out_success) {
    return vprism_parse_success_with_options(source, source_len, NULL, out_success);
}

bool
vprism_parse_success_with_options(const char *source, size_t source_len, const char *options, bool *out_success) {
    if (out_success == NULL) {
        vprism_set_error("parse success output pointer is null");
        return false;
    }

    *out_success = false;

    *out_success = pm_parse_success_p((const uint8_t *) source, source_len, options);
    vprism_clear_error();

    return true;
}

bool
vprism_dump_json(const char *source, size_t source_len, vprism_serialized_buffer_t *out) {
    return vprism_dump_json_with_options(source, source_len, NULL, out);
}

bool
vprism_dump_json_with_options(const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out) {
    return vprism_render_parse(pm_dump_json, source, source_len, options, out);
}

bool
vprism_prettyprint(const char *source, size_t source_len, vprism_serialized_buffer_t *out) {
    return vprism_prettyprint_with_options(source, source_len, NULL, out);
}

bool
vprism_prettyprint_with_options(const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out) {
    return vprism_render_parse(pm_prettyprint, source, source_len, options, out);
}

const char *
vprism_version(void) {
    return pm_version();
}

int
vprism_string_query_local(const char *source, size_t source_len, const char *encoding_name) {
    return (int) pm_string_query_local((const uint8_t *) source, source_len, encoding_name);
}

int
vprism_string_query_constant(const char *source, size_t source_len, const char *encoding_name) {
    return (int) pm_string_query_constant((const uint8_t *) source, source_len, encoding_name);
}

int
vprism_string_query_method_name(const char *source, size_t source_len, const char *encoding_name) {
    return (int) pm_string_query_method_name((const uint8_t *) source, source_len, encoding_name);
}

const char *
vprism_token_type_name(int token_type) {
    if (token_type <= 0 || token_type >= PM_TOKEN_MAXIMUM) {
        return "";
    }

    return pm_token_type_name((pm_token_type_t) token_type);
}

bool
vprism_serialize_parse_with_options(const char *source, size_t source_len, const char *options, vprism_serialized_buffer_t *out) {
    return vprism_serialize_to_buffer(pm_serialize_parse, source, source_len, options, out);
}

void
vprism_serialized_buffer_free(vprism_serialized_buffer_t *buffer) {
    if (buffer == NULL) {
        return;
    }

    free(buffer->data);
    buffer->data = NULL;
    buffer->len = 0;
}
