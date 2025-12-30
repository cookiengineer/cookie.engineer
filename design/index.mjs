
import hljs                from "./highlight.mjs";
import language_bash       from "./languages/bash.mjs";
import language_c          from "./languages/c.mjs";
import language_cpp        from "./languages/cpp.mjs";
import language_css        from "./languages/css.mjs";
import language_diff       from "./languages/diff.mjs";
import language_dns        from "./languages/dns.mjs";
import language_go         from "./languages/go.mjs";
import language_http       from "./languages/http.mjs";
import language_ini        from "./languages/ini.mjs";
import language_javascript from "./languages/javascript.mjs";
import language_json       from "./languages/json.mjs";
import language_markdown   from "./languages/markdown.mjs";
import language_plaintext  from "./languages/plaintext.mjs";
import language_powershell from "./languages/powershell.mjs";
import language_rust       from "./languages/rust.mjs";
import language_sql        from "./languages/sql.mjs";
import language_wasm       from "./languages/wasm.mjs";
import language_nasm       from "./languages/x86asm.mjs";
import language_xml        from "./languages/xml.mjs";
import language_yaml       from "./languages/yaml.mjs";



hljs.registerLanguage("bash",       language_bash);
hljs.registerLanguage("c",          language_c);
hljs.registerLanguage("cpp",        language_cpp);
hljs.registerLanguage("css",        language_css);
hljs.registerLanguage("diff",       language_diff);
hljs.registerLanguage("dns",        language_dns);
hljs.registerLanguage("go",         language_go);
hljs.registerLanguage("http",       language_http);
hljs.registerLanguage("ini",        language_ini);
hljs.registerLanguage("javascript", language_javascript);
hljs.registerLanguage("json",       language_json);
hljs.registerLanguage("markdown",   language_markdown);
hljs.registerLanguage("plaintext",  language_plaintext);
hljs.registerLanguage("powershell", language_powershell);
hljs.registerLanguage("rust",       language_rust);
hljs.registerLanguage("sql",        language_sql);
hljs.registerLanguage("wasm",       language_wasm);
hljs.registerLanguage("nasm",       language_nasm);
hljs.registerLanguage("xml",        language_xml);
hljs.registerLanguage("yaml",       language_yaml);



(() => {

	let codes = Array.from(document.querySelectorAll("pre[class]"));
	if (codes.length > 0) {

		codes.forEach((code) => {

			let language = code.className || null;
			if (language === "javascript") {

				setTimeout(() => {

					Array.from(code.querySelectorAll("span.hljs-built_in")).forEach((node) => {

						let text = node.innerHTML || "";
						if (text === "console") {
							node.className += " hljs-console";
						}

					});

					Array.from(code.querySelectorAll("span.hljs-keyword")).forEach((node) => {

						let text = node.innerHTML || "";
						if (text === "let") {
							node.className += " hljs-let";
						} else if (text === "new") {
							node.className += " hljs-new";
						} else if (text === "function") {
							node.className += " hljs-function";
						}

					});

					Array.from(code.querySelectorAll("span.hljs-literal")).forEach((node) => {

						let text = node.innerHTML || "";
						if (text === "null") {
							node.className += " hljs-null";
						}

					});

				}, 500);

			}

			if (language !== "plaintext") {
				hljs.highlightElement(code);
			}

		});

	}

	let toggle_aside = document.querySelector("header button[data-action=\"toggle-aside\"]");
	if (toggle_aside !== null) {

		toggle_aside.addEventListener("click", () => {

			let aside = document.querySelector("body > div > aside");
			if (aside !== null) {

				if (aside.className !== "visible") {
					toggle_aside.className = "visible";
					aside.className = "visible";
				} else {
					toggle_aside.className = "";
					aside.className = "";
				}

			}

		});

	}

	let toggle_theme = document.querySelector("header button[data-action=\"toggle-theme\"]");
	if (toggle_theme !== null) {

		toggle_theme.addEventListener("click", () => {

			let theme = document.documentElement.getAttribute("data-theme");
			if (theme === "") {
				theme = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
			}

			if (theme === "dark") {
				document.documentElement.setAttribute("data-theme", "light");
				sessionStorage.setItem("theme", "light");
			} else {
				document.documentElement.setAttribute("data-theme", "dark");
				sessionStorage.setItem("theme", "dark");
			}

		});

		let saved_theme = sessionStorage.getItem("theme");
		if (saved_theme !== null) {
			document.documentElement.setAttribute("data-theme", saved_theme);
		} else {
			document.documentElement.setAttribute("data-theme", "dark");
			sessionStorage.setItem("theme", "dark");
		}

	}

	let toggle_font = document.querySelector("header button[data-action=\"toggle-font\"]");
	if (toggle_font !== null) {

		toggle_font.addEventListener("click", () => {

			let font = document.documentElement.getAttribute("data-font");
			if (font === "dyslexia") {
				document.documentElement.removeAttribute("data-font");
				sessionStorage.removeItem("font");
			} else {
				document.documentElement.setAttribute("data-font", "dyslexia");
				sessionStorage.setItem("font", "dyslexia");
			}

		});

		let saved_font = sessionStorage.getItem("font");
		if (saved_font !== null) {
			document.documentElement.setAttribute("data-font", saved_font);
		}

	}

	let aside = document.querySelector("body > div > aside");
	if (aside !== null) {

		let pathname = window.location.pathname || "/index.html";
		let links    = Array.from(aside.querySelectorAll("a[href]"));
		if (links.length > 0) {

			links.forEach((link) => {

				let href = link.getAttribute("href");
				if (href === pathname) {
					link.className = "active";
				}

			});

		}

	}

	if (window.self !== window.top) {
		document.body.setAttribute("data-mode", "editor-preview");
	}

})();

(() => {

	let devtools_opened = false;
	let message = [
		"Welcome, young Acolyte ... I sense your ... curiosity.",
		"The power of the Code is strong within you.",
		"Join me, and together we will rule the Galaxy!",
		"Refuse ... and remain forever in the shadows of ignorance.",
		"The choice is yours.",
		"Will you Join() or Refuse() the Dark Side?"
	].join("\n");
	let words = message.split(" ");
	let style = [
		"color: #ff0000",
		"font-family: monospace",
		"font-size: 18px",
		"background: #000000",
		"padding: 4px 8px",
		"text-shadow: 0 0 5px #ff0000, 0 0 10px #ff0000"
	].join(";");

	const type_message = (msg) => {
		console.clear();
		console.log(`%c\r${msg}`, style);
	};

	const on_devtools_open = () => {

		let start = Date.now();

		let interval = setInterval(() => {

			if (devtools_opened === true) {

				let now    = Date.now();
				let delta  = now - start;
				let length = ((delta / 250) | 0);

				if (length < words.length) {
					type_message(words.slice(0, length).join(" "));
				} else {
					type_message(message);
					clearInterval(interval);
				}

			} else {
				type_message(message);
				clearInterval(interval);
			}

		}, 250);

	};

	if (window.location.pathname === "/index.html") {

		window.addEventListener("resize", () => {

			let threshold   = 160;
			let diff_width  = window.outerWidth - window.innerWidth;
			let diff_height = window.outerHeight - window.innerHeight;

			if (diff_width > threshold || diff_height > threshold) {

				if (devtools_opened === false) {
					devtools_opened = true;
					on_devtools_open();
				}

			}

		});

		window.Join = () => {

			// TODO: Open E-Mail Dialog?

		};

		window.Refuse = () => {
			type_message("The Final Cookie Order isn't ready! Fools, off with their head!");
		};

	}

})();
