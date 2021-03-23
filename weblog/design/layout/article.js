
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		let hljs = global.hljs || null;
		if (hljs !== null) {

			let codes = Array.from(document.querySelectorAll('pre[class]'));
			if (codes.length > 0) {

				codes.forEach((code) => {

					let lang = code.className || null;
					if (lang === 'javascript') {

						setTimeout(() => {

							Array.from(code.querySelectorAll('span.hljs-built_in')).forEach((node) => {

								let text = node.innerHTML || '';
								if (text === 'console') {
									node.className += ' hljs-console';
								}

							});

							Array.from(code.querySelectorAll('span.hljs-keyword')).forEach((node) => {

								let text = node.innerHTML || '';
								if (text === 'let') {
									node.className += ' hljs-let';
								} else if (text === 'new') {
									node.className += ' hljs-new';
								} else if (text === 'function') {
									node.className += ' hljs-function';
								}

							});

							Array.from(code.querySelectorAll('span.hljs-literal')).forEach((node) => {

								let text = node.innerHTML || '';
								if (text === 'null') {
									node.className += ' hljs-null';
								}

							});

						}, 500);

					}

					if (lang !== 'plaintext') {
						hljs.highlightElement(code);
					}

				});

			}

		}

	}, true);

})(typeof window !== 'undefined' ? window : this);

