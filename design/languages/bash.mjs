/*! `bash` grammar compiled for Highlight.js 11.11.1 */
var hljsGrammar = (function () {
	"use strict";

	/*
	 * Language: Bash
	 * Author: vah <vahtenberg@gmail.com>
	 * Contributrors: Benjamin Pannell <contact@sierrasoftworks.com>
	 * Website: https://www.gnu.org/software/bash/
	 * Category: common, scripting
	 */

	/** @type LanguageFn */
	function bash(hljs) {
		const regex = hljs.regex;
		const VAR = {};
		const BRACED_VAR = {
			begin: /\$\{/,
			end: /\}/,
			contains: [
				"self",
				{
					begin: /:-/,
					contains: [ VAR ]
				} // default values
			]
		};
		Object.assign(VAR, {
			className: "variable",
			variants: [
				{ begin: regex.concat(/\$[\w#$@?!*-][\w\d_]*/,
					// negative look-ahead tries to avoid matching patterns that are not
					// Perl at all like $ident$, @ident@, etc.
					"(?![\\w\\d])(?![$])") },
				BRACED_VAR
			]
		});

		const SUBST = {
			className: "subst",
			begin: /\$\(/,
			end: /\)/,
			contains: [ hljs.BACKSLASH_ESCAPE ]
		};
		const COMMENT = hljs.inherit(
			hljs.COMMENT(),
			{
				match: [
					/(^|\s)/,
					/#.*$/
				],
				scope: {
					2: "comment"
				}
			}
		);
		const HERE_DOC = {
			begin: /<<-?\s*(?=\w+)/,
			starts: { contains: [
				hljs.END_SAME_AS_BEGIN({
					begin: /(\w+)/,
					end: /(\w+)/,
					className: "string"
				})
			] }
		};
		const QUOTE_STRING = {
			className: "string",
			begin: /"/,
			end: /"/,
			contains: [
				hljs.BACKSLASH_ESCAPE,
				VAR,
				SUBST
			]
		};
		SUBST.contains.push(QUOTE_STRING);
		const ESCAPED_QUOTE = {
			match: /\\"/
		};
		const APOS_STRING = {
			className: "string",
			begin: /'/,
			end: /'/
		};
		const ESCAPED_APOS = {
			match: /\\'/
		};
		const ARITHMETIC = {
			begin: /\$?\(\(/,
			end: /\)\)/,
			contains: [
				{
					begin: /\d+#[0-9a-f]+/,
					className: "number"
				},
				hljs.NUMBER_MODE,
				VAR
			]
		};
		const SH_LIKE_SHELLS = [
			"fish",
			"bash",
			"zsh",
			"sh",
			"csh",
			"ksh",
			"tcsh",
			"dash",
			"scsh",
		];
		const KNOWN_SHEBANG = hljs.SHEBANG({
			binary: `(${SH_LIKE_SHELLS.join("|")})`,
			relevance: 10
		});
		const FUNCTION = {
			className: "function",
			begin: /\w[\w\d_]*\s*\(\s*\)\s*\{/,
			returnBegin: true,
			contains: [ hljs.inherit(hljs.TITLE_MODE, { begin: /\w[\w\d_]*/ }) ],
			relevance: 0
		};

		const KEYWORDS = [
			"if",
			"then",
			"else",
			"elif",
			"fi",
			"time",
			"for",
			"while",
			"until",
			"in",
			"do",
			"done",
			"case",
			"esac",
			"coproc",
			"function",
			"select"
		];

		const LITERALS = [
			"true",
			"false"
		];

		// to consume paths to prevent keyword matches inside them
		const PATH_MODE = { match: /(\/[a-z._-]+)+/ };

		// `...` command substitution (mirrors SUBST / $(...))
		const BACKTICK = {
			className: "subst",
			begin: /`/,
			end: /`/,
			contains: [
				hljs.BACKSLASH_ESCAPE,
				VAR,
				SUBST,
				QUOTE_STRING
			]
		};

		// test operators, only relevant inside `[ ... ]` / `[[ ... ]]`
		const TEST_OPERATOR = {
			className: "keyword",
			match: /-(eq|ne|lt|le|gt|ge|nt|ot|ef|o|z|n|f|d|e|s|r|w|x|h|L|p|S|b|c|g|u|k|t|O|G|N|a|v|R)\b/
		};

		// `[ ... ]` and `[[ ... ]]` test expressions
		const TEST = {
			begin: /\[\[?(?=\s)/,
			end: /\]\]?/,
			relevance: 0,
			contains: [
				TEST_OPERATOR,
				{
					className: "operator",
					match: /=~|==|!=|<=|>=/
				},
				hljs.NUMBER_MODE,
				QUOTE_STRING,
				APOS_STRING,
				VAR
			]
		};

		// value after `=` in an option or assignment
		const SHELL_VALUE = {
			begin: /=/,
			end: /(?=\s|$)/,
			excludeBegin: true,
			relevance: 0,
			contains: [
				BACKTICK,
				SUBST,
				VAR,
				QUOTE_STRING,
				APOS_STRING,
				hljs.NUMBER_MODE,
				{
					className: "string",
					match: /\S+/
				}
			]
		};

		// `--long` / `-s` command line options
		const SHELL_OPTION = {
			className: "params",
			begin: /(?<=\s|^)--?[a-zA-Z][a-zA-Z0-9_-]*/,
			end: /(?=\s|$)/,
			relevance: 0,
			contains: [ SHELL_VALUE ]
		};

		// `export key=value`, `LD_PRELOAD=...`, `--foo bar=qux`
		const SHELL_ASSIGNMENT = {
			className: "params",
			begin: /(?<=\s|^)[a-zA-Z_][a-zA-Z0-9_-]*(?==)/,
			end: /(?=\s|$)/,
			relevance: 0,
			contains: [ SHELL_VALUE ]
		};

		// `~/path` and `~user/path`
		const TILDE_PATH = { className: "string", match: /~[a-zA-Z0-9._-]*\/[^\s"'`]*/ };

		// `scheme://host:port/path?query#fragment`
		const URL = { className: "string", match: /[a-zA-Z][a-zA-Z0-9+.-]*:\/\/[^\s"'`<>]+/ };

		// `/absolute`, `./relative` and `../parent` paths
		const PATH = { className: "string", match: /(?:\.\.?\/|\/)[a-zA-Z0-9._@+*-]*(?:\/[a-zA-Z0-9._@+*-]+)*/ };

		// `*.txt`, `**/*.c` and other glob patterns
		const GLOB = { className: "string", match: /(?<=\s|^)[^\s"'`]*\*[^\s"'`]*/ };

		// redirections (`>`, `>>`, `2>&1`, `<`, `<<<`, ...)
		const REDIRECT = { className: "operator", match: /[0-9]*(?:>>|<<<|<<|&>>|>&[0-9]*|&>|>\||<\||>|<)/ };

		// pipes and command separators
		const SEPARATOR = { className: "operator", match: /&&|\|\||;|\||&/ };

		// http://www.gnu.org/software/bash/manual/html_node/Shell-Builtin-Commands.html
		const SHELL_BUILT_INS = [
			"break",
			"cd",
			"continue",
			"eval",
			"exec",
			"exit",
			"export",
			"getopts",
			"hash",
			"pwd",
			"readonly",
			"return",
			"shift",
			"test",
			"times",
			"trap",
			"umask",
			"unset"
		];

		const BASH_BUILT_INS = [
			"alias",
			"bind",
			"builtin",
			"caller",
			"command",
			"declare",
			"echo",
			"enable",
			"help",
			"let",
			"local",
			"logout",
			"mapfile",
			"printf",
			"read",
			"readarray",
			"source",
			"sudo",
			"type",
			"typeset",
			"ulimit",
			"unalias"
		];

		const ZSH_BUILT_INS = [
			"autoload",
			"bg",
			"bindkey",
			"bye",
			"cap",
			"chdir",
			"clone",
			"comparguments",
			"compcall",
			"compctl",
			"compdescribe",
			"compfiles",
			"compgroups",
			"compquote",
			"comptags",
			"comptry",
			"compvalues",
			"dirs",
			"disable",
			"disown",
			"echotc",
			"echoti",
			"emulate",
			"fc",
			"fg",
			"float",
			"functions",
			"getcap",
			"getln",
			"history",
			"integer",
			"jobs",
			"kill",
			"limit",
			"log",
			"noglob",
			"popd",
			"print",
			"pushd",
			"pushln",
			"rehash",
			"sched",
			"setcap",
			"setopt",
			"stat",
			"suspend",
			"ttyctl",
			"unfunction",
			"unhash",
			"unlimit",
			"unsetopt",
			"vared",
			"wait",
			"whence",
			"where",
			"which",
			"zcompile",
			"zformat",
			"zftp",
			"zle",
			"zmodload",
			"zparseopts",
			"zprof",
			"zpty",
			"zregexparse",
			"zsocket",
			"zstyle",
			"ztcp"
		];

		const GNU_CORE_UTILS = [
			"chcon",
			"chgrp",
			"chown",
			"chmod",
			"cp",
			"dd",
			"df",
			"dir",
			"dircolors",
			"ln",
			"ls",
			"mkdir",
			"mkfifo",
			"mknod",
			"mktemp",
			"mv",
			"realpath",
			"rm",
			"rmdir",
			"shred",
			"sync",
			"touch",
			"truncate",
			"vdir",
			"b2sum",
			"base32",
			"base64",
			"cat",
			"cksum",
			"comm",
			"csplit",
			"cut",
			"expand",
			"fmt",
			"fold",
			"head",
			"join",
			"md5sum",
			"nl",
			"numfmt",
			"od",
			"paste",
			"ptx",
			"pr",
			"sha1sum",
			"sha224sum",
			"sha256sum",
			"sha384sum",
			"sha512sum",
			"shuf",
			"sort",
			"split",
			"sum",
			"tac",
			"tail",
			"tr",
			"tsort",
			"unexpand",
			"uniq",
			"wc",
			"arch",
			"basename",
			"chroot",
			"date",
			"dirname",
			"du",
			"echo",
			"env",
			"expr",
			"factor",
			// "false", // keyword literal already
			"groups",
			"hostid",
			"id",
			"link",
			"logname",
			"nice",
			"nohup",
			"nproc",
			"pathchk",
			"pinky",
			"printenv",
			"printf",
			"pwd",
			"readlink",
			"runcon",
			"seq",
			"sleep",
			"stat",
			"stdbuf",
			"stty",
			"tee",
			"test",
			"timeout",
			// "true", // keyword literal already
			"tty",
			"uname",
			"unlink",
			"uptime",
			"users",
			"who",
			"whoami",
			"yes"
		];

		return {
			name: "Bash",
			aliases: [
				"sh",
				"zsh"
			],
			keywords: {
				$pattern: /\b[a-z][a-z0-9._-]+\b/,
				keyword: KEYWORDS,
				literal: LITERALS,
				built_in: [
					...SHELL_BUILT_INS,
					...BASH_BUILT_INS,
					// Shell modifiers
					"set",
					"shopt",
					...ZSH_BUILT_INS,
					...GNU_CORE_UTILS
				]
			},
			contains: [
				BACKTICK,
				TEST,
				SHELL_OPTION,
				SHELL_ASSIGNMENT,
				TILDE_PATH,
				URL,
				PATH,
				REDIRECT,
				SEPARATOR,
				hljs.NUMBER_MODE,
				KNOWN_SHEBANG, // to catch known shells and boost relevancy
				hljs.SHEBANG(), // to catch unknown shells but still highlight the shebang
				FUNCTION,
				ARITHMETIC,
				COMMENT,
				HERE_DOC,
				PATH_MODE,
				QUOTE_STRING,
				ESCAPED_QUOTE,
				APOS_STRING,
				ESCAPED_APOS,
				VAR,
				GLOB
			]
		};
	}

	return bash;

})();
;
export default hljsGrammar;
