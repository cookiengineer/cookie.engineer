/*! `zeek` grammar for Highlight.js 11.11.1 */
var hljsGrammar = (function () {
	"use strict";

	function zeek(hljs) {
		const KEYWORDS = [
			"event",
			"function",
			"hook",
			"module",
			"export",
			"global",
			"local",
			"const",
			"type",
			"when",
			"if",
			"else",
			"return",
			"print",
			"log",
			"add",
			"delete",
			"schedule"
		];

		return {
			name: "Zeek",
			keywords: {
				keyword: KEYWORDS.join(" ")
			},
			contains: [
				hljs.HASH_COMMENT_MODE,
				hljs.QUOTE_STRING_MODE,
				hljs.C_NUMBER_MODE
			]
		};
	}

	return zeek;

})();
export default hljsGrammar;
