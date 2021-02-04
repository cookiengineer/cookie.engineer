
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

const renderElement = function(element, indent) {

	if (typeof element === 'string') {
		return element;
	} else {

		let block = '';
		let type  = element.type;


		if (type === 'b' || type === 'code' || type === 'em' || type === 'del') {
			return ' <' + type + '>' + element.raw + '</' + type + '>';
		} else if (type === 'img') {
			return ' <img src="' + element.src + '" alt="' + element.alt + '"> ';
		} else if (type === 'a') {

			if (element.state !== '') {
				return ' <a class="' + element.state + '" href="' + element.href + '">' + element.raw + '</a> ';
			} else {
				return ' <a href="' + element.href + '">' + element.raw + '</a> ';
			}

		} else if (type === 'h1' || type === 'h2' || type === 'h3') {

			block += indent + '<' + type + '>';

			if (element.nodes.length > 0) {
				element.nodes.forEach((node, n) => {
					if (n > 0) block += ' ';
					block += renderElement(node, indent + '\t').trim();
				});
			}

			block += '</' + type + '>';

		} else if (type === 'pre') {

			block += indent + '<pre class="' + element.state + '">\n';
			block += element.raw.trim() + '\n';
			block += indent + '</pre>';

		} else if (type === 'p') {

			if (element.nodes.length === 1) {
				return indent + '<p>' + renderElement(element.nodes[0], indent) + '</p>';
			} else if (element.nodes.length > 0) {

				block += indent + '<p>\n';

				element.nodes.forEach((node) => {
					block += indent + '\t' + renderElement(node, indent + '\t') + '\n';
				});

				block += indent + '</p>';

			}

		} else if (type === 'ol' || type === 'ul') {

			block += indent + '<' + type + '>\n';

			if (element.nodes.length > 0) {
				element.nodes.forEach((node) => {
					block += indent + renderElement(node, indent + '\t');
				});
			}

			block += indent + '</' + type + '>';

		} else if (type === 'li') {

			block += indent + '<li>';

			if (element.nodes.length > 0) {
				element.nodes.forEach((node, n) => {
					if (n > 0) block += ' ';
					block += renderElement(node, indent + '\t').trim();
				});
			}

			block += '</li>\n';

		} else {

			console.warn('MARKDOWN:', element);

		}


		return block;

	}

};



/*
 * IMPLEMENTATION
 */

const parse = function(article) {

	let element  = null;
	let elements = [];

	article.split('\n').forEach((line) => {

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
			} else if (element !== null) {
				element = null;
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
			// console.log(item.nodes);
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

const render = function(elements) {

	let html = [];

	elements.forEach((element) => {
		html.push(renderElement(element, ''));
	});

	return html.join('\n').trim();

};

export const MARKDOWN = {
	parse:  parse,
	render: render
};

export default {
	parse,
	render
};

