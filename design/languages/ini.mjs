/*! `ini` grammar compiled for Highlight.js 11.11.1 */
var hljsGrammar = (function () {
	"use strict";

	/*
	 * Language: TOML, also INI
	 * Description: TOML aims to be a minimal configuration file format that's easy to read due to obvious semantics.
	 * Contributors: Guillaume Gomez <guillaume1.gomez@gmail.com>
	 * Category: common, config
	 * Website: https://github.com/toml-lang/toml
	 */

	function ini(hljs) {
		const regex = hljs.regex;
		const NUMBERS = {
			className: "number",
			relevance: 0,
			variants: [
				{ begin: /(?<![\w.+-])[-+]?\d[\d_]*(?:\.[\d_]+)?(?![\w.])/ }
			]
		};
		const COMMENTS = hljs.COMMENT();
		COMMENTS.variants = [
			{
				begin: /;/,
				end: /$/
			},
			{
				begin: /#/,
				end: /$/
			}
		];
		const VARIABLES = {
			className: "variable",
			variants: [
				{ begin: /\$[\w\d"][\w\d_]*/ },
				{ begin: /\$\{(.*?)\}/ }
			]
		};
		const LITERALS = {
			className: "literal",
			begin: /\b(?:on|off|true|false|yes|no)\b/
		};
		const STRINGS = {
			className: "string",
			contains: [ hljs.BACKSLASH_ESCAPE ],
			variants: [
				{
					begin: "'''",
					end: "'''",
					relevance: 10
				},
				{
					begin: "\"\"\"",
					end: "\"\"\"",
					relevance: 10
				},
				{
					begin: "\"",
					end: "\""
				},
				{
					begin: "'",
					end: "'"
				}
			]
		};
		const PATH = {
			className: "string",
			match: /(?:\.\.?\/|\/)[a-zA-Z0-9._@+*-]*(?:\/[a-zA-Z0-9._@+*-]+)*/,
			relevance: 0
		};
		const TILDE_PATH = {
			className: "string",
			match: /~[a-zA-Z0-9._-]*\/[^\s"'`;]*/,
			relevance: 0
		};
		const URL = {
			className: "string",
			match: /[a-zA-Z][a-zA-Z0-9+.-]*:\/\/[^\s"'`<>;]+/,
			relevance: 0
		};
		const WINDOWS_PATH = {
			className: "string",
			match: /(?:[a-zA-Z]:[\\/]|\\\\[a-zA-Z0-9._$-]+\\)[^\s#;"']*/,
			relevance: 0
		};
		const BARE_VALUE = {
			className: "string",
			match: /[^\s#;]+/,
			relevance: 0
		};
		const BARE_ELEMENT = {
			className: "string",
			match: /[^\s#;,\[\]]+/,
			relevance: 0
		};
		const ASSIGN = {
			match: /=\s*/
		};
		const ARRAY = {
			begin: /\[/,
			end: /\]/,
			contains: [
				COMMENTS,
				LITERALS,
				VARIABLES,
				STRINGS,
				PATH,
				TILDE_PATH,
				URL,
				WINDOWS_PATH,
				NUMBERS,
				BARE_ELEMENT,
				"self"
			],
			relevance: 0
		};

		const BARE_KEY = /[A-Za-z0-9_-]+/;
		const QUOTED_KEY_DOUBLE_QUOTE = /"(\\"|[^"])*"/;
		const QUOTED_KEY_SINGLE_QUOTE = /'[^']*'/;
		const ANY_KEY = regex.either(
			BARE_KEY, QUOTED_KEY_DOUBLE_QUOTE, QUOTED_KEY_SINGLE_QUOTE
		);
		const DOTTED_KEY = regex.concat(
			ANY_KEY, "(\\s*\\.\\s*", ANY_KEY, ")*",
			regex.lookahead(/\s*=\s*[^#\s]/)
		);

		return {
			name: "TOML, also INI",
			aliases: [ "toml" ],
			case_insensitive: true,
			illegal: /\S/,
			contains: [
				COMMENTS,
				{
					className: "section",
					begin: /\[+/,
					end: /\]+/
				},
				{
					begin: DOTTED_KEY,
					className: "attr",
					starts: {
						end: /$/,
						contains: [
							COMMENTS,
							ASSIGN,
							ARRAY,
							LITERALS,
							VARIABLES,
							STRINGS,
							PATH,
							TILDE_PATH,
							URL,
							WINDOWS_PATH,
							NUMBERS,
							BARE_VALUE
						]
					}
				}
			]
		};
	}

	return ini;

})();
;
export default hljsGrammar;
