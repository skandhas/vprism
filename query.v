module vprism

import vprism.ffi

const default_query_encoding = 'UTF-8'

// is_local_name checks whether value is a valid Ruby local variable name using UTF-8.
pub fn is_local_name(value string) !bool {
	return is_local_name_with_encoding(value, default_query_encoding)
}

// is_local_name_with_encoding checks whether value is a valid Ruby local variable name.
pub fn is_local_name_with_encoding(value string, encoding string) !bool {
	return ffi.string_query_local(value, encoding)
}

// is_constant_name checks whether value is a valid Ruby constant name using UTF-8.
pub fn is_constant_name(value string) !bool {
	return is_constant_name_with_encoding(value, default_query_encoding)
}

// is_constant_name_with_encoding checks whether value is a valid Ruby constant name.
pub fn is_constant_name_with_encoding(value string, encoding string) !bool {
	return ffi.string_query_constant(value, encoding)
}

// is_method_name checks whether value is a valid Ruby method name using UTF-8.
pub fn is_method_name(value string) !bool {
	return is_method_name_with_encoding(value, default_query_encoding)
}

// is_method_name_with_encoding checks whether value is a valid Ruby method name.
pub fn is_method_name_with_encoding(value string, encoding string) !bool {
	return ffi.string_query_method_name(value, encoding)
}
