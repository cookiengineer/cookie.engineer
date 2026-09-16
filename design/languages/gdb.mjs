/*! `gdb` grammar for Highlight.js 11.11.1 */
var hljsGrammar = (function () {
	"use strict";

	function gdb(hljs) {
		const KEYWORDS = [
			"run",
			"break",
			"continue",
			"next",
			"step",
			"until",
			"finish",
			"print",
			"set",
			"info",
			"backtrace",
			"disassemble",
			"examine",
			"watch",
			"catch",
			"thread",
			"apply",
			"attach",
			"detach",
			"quit",
			"list",
			"help",
			"show",
			"file",
			"core",
			"directory",
			"return",
			"call",
			"layout"
		];

		return {
			name: "GDB",
			keywords: {
				keyword: KEYWORDS.join(" ")
			},
			contains: [
				hljs.HASH_COMMENT_MODE,
				{
					className: "meta",
					begin: /^\(gdb\)/
				},
				hljs.QUOTE_STRING_MODE,
				hljs.C_NUMBER_MODE
			]
		};
	}

	return gdb;

})();
export default hljsGrammar;
