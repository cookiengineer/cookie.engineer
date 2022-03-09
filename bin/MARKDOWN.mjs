
import path        from 'path';
import { console } from './console.mjs';



const EMOJI = {
	'book':         String.fromCodePoint(0x1f4d5),
	'bug':          String.fromCodePoint(0x1f41b),
	'construction': String.fromCodePoint(0x1f6a7),
	'ghost':        String.fromCodePoint(0x1f47b),
	'rainbow':      String.fromCodePoint(0x1f308),
	'robot':        String.fromCodePoint(0x1f916),
	'rocket':       String.fromCodePoint(0x1f680),
	'satellite':    String.fromCodePoint(0x1f4e1),
	'snowflake':    String.fromCodePoint(0x2744),
	'sparkles':     String.fromCodePoint(0x2728)
};

const toElement = (type) => ({
	type:  type,
	raw:   '',
	state: '',
	nodes: []
});

const parseChunk = function(str) {

	str = str.trim();


	let element  = null;
	let elements = [];

	while (str.length > 0) {

		let check_emoji = str.startsWith(':');
		let check_img   = str.startsWith('![') && str.includes('](') && str.includes(')');
		let check_b     = str.startsWith('**');
		let check_code  = str.startsWith('`');
		let check_em    = str.startsWith('*');
		let check_del   = str.startsWith('~');
		let check_a     = str.startsWith('[') && str.includes('](') && str.includes(')');

		// XXX: Debugging
		// console.log(str.split('\n')[0], check_a, check_b, check_em, check_img, check_emoji);

		if (check_emoji === true) {

			let i1 = str.indexOf(':', 1);
			if (i1 !== -1) {

				let tmp = str.substr(0, i1);
				let emoji = EMOJI[tmp] || null;
				if (emoji !== null) {
					elements.push(emoji);
				} else {
					elements.push(tmp);
				}

				str = str.substr(i1);

			} else {
				elements.push(str.substr(0, 1));
				str = str.substr(1);
			}

		} else if (check_img === true) {

			let i1 = str.indexOf('](', 2);
			let i2 = str.indexOf(')', 2);

			if (i1 !== -1 && i2 !== -1) {

				let alt = str.substr(2, i1 - 2);
				let src = str.substr(i1 + 2, i2 - i1 - 2);

				element = toElement('img');
				element.src = src;
				element.alt = alt;
				elements.push(element);

				str = str.substr(i2 + 1);

			} else {
				elements.push(str.substr(0, 2));
				str = str.substr(2);
			}

		} else if (check_b === true) {

			let c1 = str.indexOf('**', 2);
			if (c1 !== -1) {

				element = toElement('b');
				element.raw = str.substr(2, c1 - 2);
				elements.push(element);

				str = str.substr(c1 + 2);

			} else {
				elements.push(str.substr(0, 2));
				str = str.substr(2);
			}

		} else if (check_code === true) {

			let c1 = str.indexOf('`', 1);
			if (c1 !== -1) {

				element = toElement('code');
				element.raw = str.substr(1, c1 - 1);
				elements.push(element);

				str = str.substr(c1 + 1);

			} else {
				elements.push(str.substr(0, 1));
				str = str.substr(1);
			}

		} else if (check_em === true) {

			let c1 = str.indexOf('*', 1);
			if (c1 !== -1) {

				element = toElement('em');
				element.raw = str.substr(1, c1 - 1);
				elements.push(element);

				str = str.substr(c1 + 1);

			} else {
				elements.push(str.substr(0, 1));
				str = str.substr(1);
			}

		} else if (check_del === true) {

			let c1 = str.indexOf('~', 1);
			if (c1 !== -1) {

				element = toElement('del');
				element.raw = str.substr(1, c1 - 1);
				elements.push(element);

				str = str.substr(c1 + 1);

			} else {
				elements.push(str.substr(0, 1));
				str = str.substr(1);
			}

		} else if (check_a === true) {

			let c1 = str.indexOf('](', 1);
			let c2 = str.indexOf(')', c1 + 1);

			if (c1 !== -1 && c2 !== -1) {

				let raw  = str.substr(1, c1 - 1);
				let href = str.substr(c1 + 2, c2 - c1 - 2);

				element = toElement('a');
				element.href = href;
				element.raw  = raw;
				elements.push(element);

				str = str.substr(c2 + 1);

			} else {
				elements.push(str.substr(0, 2));
				str = str.substr(2);
			}

		} else {

			let i1 = str.indexOf(':');
			let i2 = str.indexOf('![');
			let i3 = str.indexOf('**');
			let i4 = str.indexOf('`');
			let i5 = str.indexOf('*');
			let i6 = str.indexOf('~');
			let i7 = str.indexOf('[');

			let i0 = Infinity;
			if (i1 !== -1) i0 = Math.min(i0, i1);
			if (i2 !== -1) i0 = Math.min(i0, i2);
			if (i3 !== -1) i0 = Math.min(i0, i3);
			if (i4 !== -1) i0 = Math.min(i0, i4);
			if (i5 !== -1) i0 = Math.min(i0, i5);
			if (i6 !== -1) i0 = Math.min(i0, i6);
			if (i7 !== -1) i0 = Math.min(i0, i7);

			if (i0 !== Infinity) {
				elements.push(str.substr(0, i0));
				str = str.substr(i0);
			} else {
				elements.push(str);
				str = '';
			}

		}

	}

	return elements;

};

const renderElement = function(element, indent, root) {

	root = typeof root === 'string' ? root : null;


	if (typeof element === 'string') {
		return element;
	} else {

		let block = '';
		let type  = element.type;


		if (type === 'b' || type === 'code' || type === 'em' || type === 'del') {
			return ' <' + type + '>' + element.raw + '</' + type + '>';
		} else if (type === 'img') {

			if (root !== null) {

				if (element.src.startsWith('../')) {
					element.src = path.resolve(root, element.src);
				} else if (element.src.startsWith('./')) {
					element.src = path.resolve(root, element.src);
				}

			}


			return ' <img src="' + element.src + '" alt="' + element.alt + '"> ';

		} else if (type === 'a') {

			if (element.href.startsWith('https://github.com')) {
				element.state = 'icon-github';
			} else if (element.href.startsWith('https://gitlab.com')) {
				element.state = 'icon-gitlab';
			} else if (element.href.startsWith('https://instagram.com')) {
				element.state = 'icon-instagram';
			} else if (element.href.startsWith('https://linkedin.com')) {
				element.state = 'icon-linkedin';
			} else if (element.href.startsWith('https://medium.com')) {
				element.state = 'icon-medium';
			} else if (element.href.startsWith('https://reddit.com')) {
				element.state = 'icon-reddit';
			} else if (element.href.startsWith('https://') || element.href.startsWith('http://')) {
				element.state = 'icon-website';
			}

			if (
				element.href.endsWith('.js')
				|| element.href.endsWith('.mjs')
				|| element.href.endsWith('.pdf')
				|| element.href.endsWith('.tar.gz')
				|| element.href.endsWith('.tar.xz')
				|| element.href.endsWith('.zip')
			) {
				element.state = 'icon-download';
			} else if (element.href.startsWith('/')) {
				element.state = 'icon-section';
			}

			if (root !== null) {

				if (element.href.startsWith('../')) {
					element.href = path.resolve(root, element.href);
				} else if (element.href.startsWith('./')) {
					element.href = path.resolve(root, element.href);
				}

			}

			let internal = (
				element.href.startsWith('https://cookie.engineer/')
				|| element.href.startsWith('/')
				|| element.href.startsWith('./')
			);

			if (element.state !== '') {

				if (internal === true) {
					return ' <a class="' + element.state + '" href="' + element.href + '">' + element.raw + '</a> ';
				} else {
					return ' <a class="' + element.state + '" href="' + element.href + '" target="_blank">' + element.raw + '</a> ';
				}

			} else {

				if (internal === true) {
					return ' <a href="' + element.href + '">' + element.raw + '</a> ';
				} else {
					return ' <a href="' + element.href + '" target="_blank">' + element.raw + '</a> ';
				}

			}

		} else if (type === 'h1' || type === 'h2' || type === 'h3') {

			block += indent + '<' + type + '>';

			if (element.nodes.length > 0) {
				element.nodes.forEach((node, n) => {
					if (n > 0) block += ' ';
					block += renderElement(node, indent + '\t', root).trim();
				});
			}

			block += '</' + type + '>';

		} else if (type === 'pre') {

			block += indent + '<pre class="' + element.state + '">\n';
			block += element.raw.trim() + '\n';
			block += indent + '</pre>';

		} else if (type === 'p') {

			if (element.nodes.length === 1) {
				return indent + '<p>' + renderElement(element.nodes[0], indent, root) + '</p>';
			} else if (element.nodes.length > 0) {

				block += indent + '<p>\n';

				element.nodes.forEach((node) => {
					block += indent + '\t' + renderElement(node, indent + '\t', root) + '\n';
				});

				block += indent + '</p>';

			}

		} else if (type === 'ol' || type === 'ul') {

			block += indent + '<' + type + '>\n';

			if (element.nodes.length > 0) {
				element.nodes.forEach((node) => {
					block += indent + renderElement(node, indent + '\t', root);
				});
			}

			block += indent + '</' + type + '>';

		} else if (type === 'li') {

			block += indent + '<li>';

			if (element.nodes.length > 0) {
				element.nodes.forEach((node, n) => {
					if (n > 0) block += ' ';
					block += renderElement(node, indent + '\t', root).trim();
				});
			}

			block += '</li>\n';

		} else {

			console.warn('MARKDOWN:', element);

		}


		return block;

	}

};

const parseBody = function(body) {

	body = typeof body === 'string' ? body : '';


	let element  = null;
	let elements = [];

	body.split('\n').forEach((line) => {

		let chunk = line.trim();
		if (chunk === '' && element !== null) {

			if (/^(hr|pre|ul|ol|p)$/g.test(element.type) === false) {
				element = null;
			}

		}

		if (element !== null && element.type === 'pre') {

			if (chunk === '```') {
				element = null;
			} else {
				element.raw += '\n' + line;
			}

		} else if (element !== null && element.type === 'p') {

			if (chunk === '') {
				element = null;
			} else {

				parseChunk(' ' + chunk).forEach((node) => {
					element.nodes.push(node);
				});

			}

		} else if (chunk.startsWith('```')) {

			if (element === null || element.type !== 'pre') {
				element = toElement('pre');
				element.raw = '';
			}

			if (chunk.length > 3) {
				element.state = chunk.substr(3).split(' ')[0].trim();
			}

		} else if (chunk.startsWith('#')) {

			let type = null;
			let tmp  = chunk.split(' ')[0].trim();

			if (tmp === '#') {
				type = 'h1';
			} else if (tmp === '##') {
				type = 'h2';
			} else if (tmp === '###') {
				type = 'h3';
			}

			if (type !== null) {
				element       = toElement(type);
				element.nodes = parseChunk(chunk.split(' ').slice(1).join(' '));
			}

		} else if (chunk.startsWith('* ') || chunk.startsWith('- ')) {

			if (element === null || element.type !== 'ul') {
				element = toElement('ul');
			}

			let item = toElement('li');
			item.nodes = parseChunk(chunk.substr(2).trim());
			element.nodes.push(item);

		} else if (/^([0-9]+)\./g.test(chunk)) {

			if (element === null || element.type !== 'ol') {
				element = toElement('ol');
			}

			let item = toElement('li');
			item.nodes = parseChunk(chunk.split('.').slice(1).join('.').trim());
			element.nodes.push(item);

		} else if (chunk !== '') {

			if (element === null || element.type !== 'p') {
				element = toElement('p');
			}

			parseChunk(' ' + chunk).forEach((node) => {
				element.nodes.push(node);
			});

		}


		if (element !== null && elements.includes(element) === false) {
			elements.push(element);
		}

	});

	return elements;

};

const parseMeta = function(meta) {

	meta = typeof meta === 'string' ? meta : '';


	let data = {
		crux: null,
		date: null,
		name: null,
		tags: [],
		time: null,
		type: [],
		word: null
	};

	meta.split('\n').forEach((line) => {

		if (line.startsWith('-') && line.includes(':')) {

			line = line.substr(1);


			let tmp = line.trim().split(':');
			let key = tmp[0].trim();
			let val = tmp[1].trim();

			if (key === 'tags' || key === 'type') {
				data[key] = val.split(',').map((v) => v.trim());
			} else {
				data[key] = val;
			}

		}

	});


	if (
		typeof data.date === 'string'
		&& /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/g.test(data.date)
		&& data.name !== null
		&& data.tags.length > 0
		&& data.type.length > 0
	) {
		return data;
	}


	return null;

};



export const MARKDOWN = {

	parse: (buffer /*, root */) => {

		buffer = typeof buffer === 'string' ? buffer : null;
		// root   = typeof root === 'string'   ? root   : null;


		let data = {
			meta: {},
			body: []
		};

		if (buffer !== null) {

			buffer = buffer.trim();

			if (buffer.startsWith('===')) {

				let meta = parseMeta(buffer.substr(3, buffer.indexOf('===', 3) - 3).trim());
				if (meta !== null) {
					data.meta = meta;
				}

				let body = parseBody(buffer.substr(buffer.indexOf('===', 3) + 3).trim());
				if (body.length > 0) {
					data.body = body;
				}

				let words = buffer.substr(buffer.indexOf('===', 3) + 3).trim().split('\n').join(' ').split(' ').filter((word) => {
					return /[A-Za-z]+/g.test(word) === true;
				});

				if (words.length > 1) {
					data.meta.word = words.length;
					data.meta.time = Math.round(words.length / 200);
				}

			} else {

				data.meta = {
					crux: null,
					date: null,
					name: null,
					tags: [],
					time: null,
					type: [],
					word: null
				};

				let body = parseBody(buffer);
				if (body.length > 0) {
					data.body = body;
				}

				let words = buffer.trim().split('\n').join(' ').split(' ').filter((word) => {
					return /[A-Za-z]+/g.test(word) === true;
				});

				if (words.length > 1) {
					data.meta.word = words.length;
					data.meta.time = Math.round(words.length / 200);
				}

			}

		}


		return data;

	},

	render: (data, root) => {

		data = data instanceof Object   ? data : null;
		root = typeof root === 'string' ? root : null;


		let result = {
			meta: null,
			body: null
		};

		if (data !== null) {

			result.meta = MARKDOWN.renderMeta(data.meta || null, root);
			result.body = MARKDOWN.renderBody(data.body || null, root);

		}

		return result;

	},

	renderBody: (body, root) => {

		body = body instanceof Array    ? body : null;
		root = typeof root === 'string' ? root : null;


		let result = null;

		if (body !== null) {

			let html = [];

			body.forEach((element) => {
				html.push(renderElement(element, '', root));
			});

			if (html.length > 0) {
				result = html.join('\n').trim();
			}

		}

		return result;

	},

	renderMeta: (/* meta, root */) => {

		// TODO: renderMeta() should return a string with <meta> tags
		return null;

	},

	renderTemplate: (temp, data) => {

		temp = typeof temp === 'string' ? temp : '';
		data = data instanceof Object   ? data : null;


		let result = temp;

		Object.keys(data).forEach((key) => {

			let val = data[key] || null;
			if (val !== null) {

				if (val instanceof Array) {
					result = result.split('${' + key + '}').join(val.join(', '));
				} else if (typeof val === 'string') {
					result = result.split('${' + key + '}').join(val);
				}

			}

		});

		return result;

	}

};

export default { MARKDOWN };

