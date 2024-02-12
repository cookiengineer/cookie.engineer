
document.addEventListener('DOMContentLoaded', () => {

	const filename = document.querySelector('select[data-key="filename"]');
	const editor   = document.querySelector('textarea[data-key="editor"]');
	const iframe   = document.querySelector('aside iframe');
	const FILE     = {
		name:   null,
		buffer: null
	};

	const format = (str, length) => {

		if (str.length < length) {
			return new Array(length - str.length).fill('0').join('') + str;
		}

		return str;

	};

	const datetime = () => {

		let name = '';
		let date = new Date();

		name += date.getFullYear();
		name += '-';
		name += format('' + date.getUTCMonth(), 2);
		name += '-';
		name += format('' + date.getUTCDate(), 2);

		return name;

	};

	const refresh = () => {

		let xhr = new XMLHttpRequest();

		xhr.open('GET', '/weblog/articles/*.md');
		xhr.responseType = 'json';

		xhr.onerror   = () => {};
		xhr.ontimeout = () => {};

		xhr.onload = () => {

			let response = xhr.response || [];
			if (response.length > 0) {

				let draft = 'draft-' + datetime() + '.md';
				let html  = [];

				html.push('<option value="' + draft + '">- create new article (as "' + draft + '") -</option>');

				response.forEach((filename) => {
					html.push('<option value="' + filename + '">' + filename + '</option>');
				});

				filename.innerHTML = html.join('');

			}

		};

		xhr.send(null);

	};

	const update = () => {

		iframe.setAttribute('src', '/weblog/articles/' + FILE.name.split('.').slice(0, -1).join('.') + '.html');

	};

	const read = (filename, callback) => {

		let xhr = new XMLHttpRequest();

		xhr.open('GET', '/weblog/articles/' + filename);
		xhr.responseType = 'text';

		xhr.onerror = () => {
			callback('');
		};

		xhr.ontimeout = () => {
			callback('');
		};

		xhr.onload = () => {

			if (xhr.status === 200) {

				callback(xhr.response);

			} else {

				if (filename.startsWith('draft-')) {

					callback([
						'===',
						'- date: ' + datetime(),
						'- name: Cookie\'s Thoughts about Web Logs',
						'- tags: networking, nodejs, privacy, security',
						'- type: hardware, software, research, legacy',
						'- crux: Yet another story from Cookie Engineer...',
						'===',
						'',
						'This is the overview of the article.',
						'',
						'',
						'## Introduction',
						'',
						'...'
					].join('\n'));

				} else {
					callback('');
				}

			}

		};

		xhr.send(null);

	};

	const save = (filename, buffer, callback) => {

		let xhr = new XMLHttpRequest();

		xhr.open('POST', '/weblog/articles/' + filename);

		xhr.onerror = () => {

			if (xhr.status === 200) {
				callback(true);
			} else {
				callback(false);
			}

		};

		xhr.ontimeout = () => {
			callback(false);
		};

		xhr.onload = () => {

			if (xhr.status === 200) {
				callback(true);
			} else {
				callback(false);
			}

		};

		xhr.send(buffer);

	};



	filename.onchange = () => {

		read(filename.value.trim(), (buffer) => {

			if (buffer.length > 0) {
				FILE.name   = filename.value.trim();
				FILE.buffer = buffer;
			}

			editor.value = buffer;

			update();

		});

	};

	editor.onblur = () => {

		if (FILE.name !== null && FILE.buffer !== null) {

			let buffer = editor.value;
			if (buffer !== FILE.buffer) {

				save(FILE.name, buffer, (result) => {

					if (result === true) {

						FILE.buffer = buffer;

						setTimeout(() => {
							update();
						}, 0);

					}

				});

			}

		}

	};

	refresh();

});
