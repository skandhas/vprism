module vprism

import vprism.analysis
import vprism.serialize

// new_analyzer creates a high-level analyzer for a decoded Ruby source.
pub fn new_analyzer(result ParseResult) analysis.Analyzer {
	return analysis.new_analyzer(serialize.ParseResult(result))
}
