/*! `yara` grammar for Highlight.js 11.11.1 */
var hljsGrammar = (function () {
	"use strict";

	function yara(hljs) {
		const KEYWORDS = [
			"rule",
			"private",
			"global",
			"meta",
			"strings",
			"condition",
			"and",
			"or",
			"not",
			"all",
			"any",
			"of",
			"them",
			"for",
			"in",
			"at",
			"filesize",
			"entrypoint",
			"true",
			"false",
			"uint8",
			"uint16",
			"uint32",
			"int8",
			"int16",
			"int32"
		];

		return {
			name: "YARA",
			keywords: {
				keyword: KEYWORDS.join(" ")
			},
			contains: [
				hljs.HASH_COMMENT_MODE,
				hljs.QUOTE_STRING_MODE,
				hljs.C_NUMBER_MODE,
				{
					className: "string",
					begin: /\/[^/\n]*\//
				}
			]
		};
	}

	return yara;

})();
export default hljsGrammar;
