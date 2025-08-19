document.addEventListener('DOMContentLoaded', () => {

	const editor  = document.querySelector('textarea[data-key="editor"]');
	const languages = [
		'c',
		'cc',
		'docker',
		'golang',
		'h',
		'hh',
		'http',
		'https',
		'html',
		'js',
		'jsx',
		'mjs',
		'patch',
		'rss',
		'sh',
		'svg',
		'toml',
		'xhtml',
	];
	const toolbar = {
		// headlines
		h1: document.querySelector('header button[data-key="h1"]'),
		h2: document.querySelector('header button[data-key="h2"]'),
		h3: document.querySelector('header button[data-key="h3"]'),

		// inline formatting
		bold:   document.querySelector('header button[data-key="bold"]'),
		italic: document.querySelector('header button[data-key="italic"]'),
		del:    document.querySelector('header button[data-key="del"]'),
		quote:  document.querySelector('header button[data-key="quote"]'),
		code:   document.querySelector('header button[data-key="code"]'),
		link:   document.querySelector('header button[data-key="link"]'),
		image:  document.querySelector('header button[data-key="image"]'),

		// lists
		list_unordered: document.querySelector('header button[data-key="list-unordered"]'),
		list_ordered:   document.querySelector('header button[data-key="list-ordered"]'),
		list_task:      document.querySelector('header button[data-key="list-task"]')
	};

	const select_block = () => {

		let prefix = editor.value.substr(0, editor.selectionStart);
		let suffix = editor.value.substr(editor.selectionEnd);
		let line   = editor.value.substr(editor.selectionStart, editor.selectionEnd - editor.selectionStart);

		if (prefix.indexOf('\n\n') !== -1) {

			let index = prefix.lastIndexOf('\n\n', editor.selectionStart);

			line   = prefix.substr(index + 2) + line;
			prefix = prefix.substr(0, index + 2);

		} else {

			line   = prefix + line;
			prefix = '';

		}

		if (suffix.indexOf('\n\n') !== -1) {

			let index = suffix.indexOf('\n\n');

			line   = line + suffix.substr(0, index);
			suffix = suffix.substr(index);

		} else {

			line   = line + suffix;
			suffix = '';

		}

		return {
			prefix:    prefix,
			selection: line,
			suffix:    suffix
		};

	};

	const select_line = () => {

		let prefix = editor.value.substr(0, editor.selectionStart);
		let suffix = editor.value.substr(editor.selectionEnd);
		let line   = editor.value.substr(editor.selectionStart, editor.selectionEnd - editor.selectionStart);

		if (prefix.indexOf('\n') !== -1) {

			let index = prefix.lastIndexOf('\n', editor.selectionStart);

			line   = prefix.substr(index + 1) + line;
			prefix = prefix.substr(0, index + 1);

		} else {

			line   = prefix + line;
			prefix = '';

		}

		if (suffix.indexOf('\n') !== -1) {

			let index = suffix.indexOf('\n');

			line   = line + suffix.substr(0, index);
			suffix = suffix.substr(index);

		} else {

			line   = line + suffix;
			suffix = '';

		}

		return {
			prefix:    prefix,
			selection: line,
			suffix:    suffix
		};

	};

	const select_word = () => {

		let prefix = editor.value.substr(0, editor.selectionStart);
		let suffix = editor.value.substr(editor.selectionEnd);
		let word   = editor.value.substr(editor.selectionStart, editor.selectionEnd - editor.selectionStart);

		if (prefix.indexOf(' ') !== -1) {

			let index = prefix.lastIndexOf(' ', editor.selectionStart);
			let limit = prefix.lastIndexOf('\n');
			if (limit !== -1 && index < limit) {
				index = limit;
			}

			word   = prefix.substr(index + 1) + word;
			prefix = prefix.substr(0, index + 1);

		} else {

			let limit = prefix.lastIndexOf('\n');
			if (limit !== -1) {
				word   = prefix.substr(limit + 1) + word;
				prefix = prefix.substr(0, limit + 1);
			} else {
				word   = prefix + word;
				prefix = '';
			}

		}

		if (suffix.indexOf(' ') !== -1) {

			let index = suffix.indexOf(' ');
			let limit = suffix.indexOf('\n');
			if (limit !== -1 && index > limit) {
				index = limit;
			}

			word   = word + suffix.substr(0, index);
			suffix = suffix.substr(index);

		} else {

			let limit = suffix.indexOf('\n');
			if (limit !== -1) {
				word   = word + suffix.substr(0, limit);
				suffix = suffix.substr(limit);
			} else {
				word   = word + suffix;
				suffix = '';
			}

		}

		return {
			prefix:    prefix,
			selection: word,
			suffix:    suffix
		};

	};

	if (toolbar.h1 !== null) {

		toolbar.h1.addEventListener('click', () => {

			let { prefix, selection, suffix } = select_line();

			if (selection.startsWith('# ') === true) {
				selection = selection.substr(2).trim();
			} else if (selection.startsWith('## ') === true) {
				selection = '# ' + selection.substr(3).trim();
			} else if (selection.startsWith('### ') === true) {
				selection = '# ' + selection.substr(4).trim();
			} else {
				selection = '# ' + selection;
			}

			editor.value = prefix + selection + suffix;
			editor.selectionStart = prefix.length;
			editor.selectionEnd = prefix.length + selection.length;
			editor.focus();

		});

	}

	if (toolbar.h2 !== null) {

		toolbar.h2.addEventListener('click', () => {

			let { prefix, selection, suffix } = select_line();

			if (selection.startsWith('# ') === true) {
				selection = '## ' + selection.substr(2).trim();
			} else if (selection.startsWith('## ') === true) {
				selection = selection.substr(3).trim();
			} else if (selection.startsWith('### ') === true) {
				selection = '## ' + selection.substr(4).trim();
			} else {
				selection = '## ' + selection;
			}

			editor.value = prefix + selection + suffix;
			editor.selectionStart = prefix.length;
			editor.selectionEnd = prefix.length + selection.length;
			editor.focus();

		});

	}

	if (toolbar.h3 !== null) {

		toolbar.h3.addEventListener('click', () => {

			let { prefix, selection, suffix } = select_line();

			if (selection.startsWith('# ') === true) {
				selection = '### ' + selection.substr(2).trim();
			} else if (selection.startsWith('## ') === true) {
				selection = '### ' + selection.substr(3).trim();
			} else if (selection.startsWith('### ') === true) {
				selection = selection.substr(4).trim();
			} else {
				selection = '### ' + selection;
			}

			editor.value = prefix + selection + suffix;
			editor.selectionStart = prefix.length;
			editor.selectionEnd = prefix.length + selection.length;
			editor.focus();

		});

	}

	if (toolbar.bold !== null) {

		toolbar.bold.addEventListener('click', () => {

			let { prefix, selection, suffix } = select_word();

			if (selection.startsWith('**') === true && selection.endsWith('**') === true) {
				selection = selection.substr(2, selection.length - 4).trim();
			} else if (selection.startsWith('*') === true && selection.endsWith('*') === true) {
				selection = '**' + selection.substr(1, selection.length - 2).trim() + '**';
			} else if (selection.startsWith('`') === true && selection.endsWith('`') === true) {
				selection = '**' + selection.substr(1, selection.length - 2).trim() + '**';
			} else if (selection.startsWith('~') === true && selection.endsWith('~') === true) {
				selection = '**' + selection.substr(1, selection.length - 2).trim() + '**';
			} else {
				selection = '**' + selection + '**';
			}

			editor.value = prefix + selection + suffix;
			editor.selectionStart = prefix.length;
			editor.selectionEnd = prefix.length + selection.length;
			editor.focus();

		});

	}

	if (toolbar.italic !== null) {

		toolbar.italic.addEventListener('click', () => {

			let { prefix, selection, suffix } = select_word();

			if (selection.startsWith('**') === true && selection.endsWith('**') === true) {
				selection = '*' + selection.substr(2, selection.length - 4).trim() + '*';
			} else if (selection.startsWith('*') === true && selection.endsWith('*') === true) {
				selection = selection.substr(1, selection.length - 2).trim();
			} else if (selection.startsWith('`') === true && selection.endsWith('`') === true) {
				selection = '*' + selection.substr(1, selection.length - 2).trim() + '*';
			} else if (selection.startsWith('~') === true && selection.endsWith('~') === true) {
				selection = '*' + selection.substr(1, selection.length - 2).trim() + '*';
			} else {
				selection = '*' + selection + '*';
			}

			editor.value = prefix + selection + suffix;
			editor.selectionStart = prefix.length;
			editor.selectionEnd = prefix.length + selection.length;
			editor.focus();

		});

	}

	if (toolbar.del !== null) {

		toolbar.del.addEventListener('click', () => {

			let { prefix, selection, suffix } = select_word();

			if (selection.startsWith('**') === true && selection.endsWith('**') === true) {
				selection = '~' + selection.substr(2, selection.length - 4).trim() + '~';
			} else if (selection.startsWith('*') === true && selection.endsWith('*') === true) {
				selection = '~' + selection.substr(1, selection.length - 2).trim() + '~';
			} else if (selection.startsWith('`') === true && selection.endsWith('`') === true) {
				selection = '~' + selection.substr(1, selection.length - 2).trim() + '~';
			} else if (selection.startsWith('~') === true && selection.endsWith('~') === true) {
				selection = selection.substr(1, selection.length - 2).trim();
			} else {
				selection = '~' + selection + '~';
			}

			editor.value = prefix + selection + suffix;
			editor.selectionStart = prefix.length;
			editor.selectionEnd = prefix.length + selection.length;
			editor.focus();

		});

	}

	if (toolbar.quote !== null) {

		toolbar.quote.addEventListener('click', () => {

			let { prefix, selection, suffix } = select_word();

			if (selection.startsWith('**') === true && selection.endsWith('**') === true) {
				selection = '`' + selection.substr(2, selection.length - 4).trim() + '`';
			} else if (selection.startsWith('*') === true && selection.endsWith('*') === true) {
				selection = '`' + selection.substr(1, selection.length - 2).trim() + '`';
			} else if (selection.startsWith('`') === true && selection.endsWith('`') === true) {
				selection = selection.substr(1, selection.length - 2).trim();
			} else if (selection.startsWith('~') === true && selection.endsWith('~') === true) {
				selection = '`' + selection.substr(1, selection.length - 2).trim() + '`';
			} else {
				selection = '`' + selection + '`';
			}

			editor.value = prefix + selection + suffix;
			editor.selectionStart = prefix.length;
			editor.selectionEnd = prefix.length + selection.length;
			editor.focus();

		});

	}

	if (toolbar.code !== null) {

		toolbar.code.addEventListener('click', () => {

			let { prefix, selection, suffix } = select_block();

			let first_line = selection.split('\n').shift();
			let last_line  = selection.split('\n').pop();

			if (first_line.startsWith('```') === true && last_line === '```') {

				let tmp = selection.split('\n');
				if (tmp.length >= 2) {
					selection = tmp.slice(1, tmp.length - 1).join('\n');
				}

			} else {

				let language = window.prompt('Enter programming language:\n\n' + languages.sort().join(', '), '');
				if (language !== null && language !== '') {
					selection = '```' + language + '\n' + selection + '\n```';
				} else {
					selection = '```\n' + selection + '\n```';
				}

			}

			editor.value = prefix + selection + suffix;
			editor.selectionStart = prefix.length;
			editor.selectionEnd = prefix.length + selection.length;
			editor.focus();

		});

	}

	if (toolbar.link !== null) {

		toolbar.link.addEventListener('click', () => {

			let { prefix, selection, suffix } = select_word();

			if (selection.startsWith('[') === true && selection.includes('](') === true && selection.endsWith(')') === true) {
				selection = selection.substr(1, selection.indexOf('](') - 1).trim();
			} else {

				let url = window.prompt('Enter URL:', '');
				if (url !== null && url !== '') {
					selection = '[' + selection + '](' + url + ')';
				} else {
					selection = '[' + selection + '](...)';
				}

			}

			editor.value = prefix + selection + suffix;
			editor.selectionStart = prefix.length;
			editor.selectionEnd = prefix.length + selection.length;
			editor.focus();

		});

	}

	if (toolbar.image !== null) {

		toolbar.image.addEventListener('click', () => {

			let { prefix, selection, suffix } = select_word();

			if (selection.startsWith('![') === true && selection.includes('](') === true && selection.endsWith(')') === true) {
				selection = selection.substr(2, selection.indexOf('](') - 2).trim();
			} else {

				let url = window.prompt('Enter Image URL:', '');
				if (url !== null && url !== '') {
					selection = '![' + selection + '](' + url + ')';
				} else {
					selection = '![' + selection + '](...)';
				}

			}

			editor.value = prefix + selection + suffix;
			editor.selectionStart = prefix.length;
			editor.selectionEnd = prefix.length + selection.length;
			editor.focus();

		});

	}

	if (toolbar.list_unordered !== null) {

		toolbar.list_unordered.addEventListener('click', () => {

			const regexp_ul = /^([*\-+]+)\s/;
			const regexp_ol = /^([0-9]+)\.\s/;

			let { prefix, selection, suffix } = select_line();

			if (selection.startsWith('- [ ]') === true || selection.startsWith('- [x]') === true) {
				selection = '- ' + selection.substr(5).trim();
			} else if (regexp_ul.test(selection) === true) {
				selection = selection.split(' ').slice(1).join(' ').trim();
			} else if (regexp_ol.test(selection) === true) {
				selection = '- ' + selection.split(' ').slice(1).join(' ').trim();
			} else {
				selection = '- ' + selection;
			}

			editor.value = prefix + selection + suffix;
			editor.selectionStart = prefix.length;
			editor.selectionEnd = prefix.length + selection.length;
			editor.focus();

		});

	}

	if (toolbar.list_ordered !== null) {

		toolbar.list_ordered.addEventListener('click', () => {

			const regexp_ul = /^([*\-+]+)\s/;
			const regexp_ol = /^([0-9]+)\.\s/;

			let { prefix, selection, suffix } = select_line();

			let index  = prefix.lastIndexOf('\n\n');
			let number = 1;

			if (regexp_ol.test(selection) === false && index !== -1) {

				let lines = prefix.substr(index + 2).trim().split('\n');

				for (let l = 0; l < lines.length; l++) {

					let line = lines[l];

					if (regexp_ol.test(line) === true) {

						let num = -1;

						try {
							num = parseInt(line.split('.').shift(), 10);
						} catch(err) {
							num = -1;
						}

						if (num !== -1) {

							if (num >= number) {
								number = num + 1;
							}

						}

					}

				}

			}

			if (selection.startsWith('- [ ]') === true || selection.startsWith('- [x]') === true) {
				selection = (number).toString() + '. ' + selection.substr(5).trim();
			} else if (regexp_ul.test(selection) === true) {
				selection = (number).toString() + '. ' + selection.split(' ').slice(1).join(' ').trim();
			} else if (regexp_ol.test(selection) === true) {
				selection = selection.split(' ').slice(1).join(' ').trim();
			} else {
				selection = (number).toString() + '. ' + selection;
			}

			editor.value = prefix + selection + suffix;
			editor.selectionStart = prefix.length;
			editor.selectionEnd = prefix.length + selection.length;
			editor.focus();

		});

	}

});

