module serialize

// FormatVersion stores the serialized Prism format version.
pub struct FormatVersion {
pub:
	// major is the major format version.
	major u32

	// minor is the minor format version.
	minor u32

	// patch is the patch format version.
	patch u32
}

// supported_format_version returns the Prism serialization format supported by this package.
pub fn supported_format_version() FormatVersion {
	return FormatVersion{
		major: 1
		minor: 9
		patch: 0
	}
}

// str returns the dotted string representation of this format version.
pub fn (version FormatVersion) str() string {
	return '${version.major}.${version.minor}.${version.patch}'
}

// matches reports whether this format version is equal to another version.
pub fn (version FormatVersion) matches(other FormatVersion) bool {
	return version.major == other.major && version.minor == other.minor
		&& version.patch == other.patch
}

// ensure_supported returns an error when this format version is not supported.
pub fn (version FormatVersion) ensure_supported() ! {
	supported := supported_format_version()

	if !version.matches(supported) {
		return error('unsupported Prism serialization version ${version}; vprism supports ${supported}')
	}
}
