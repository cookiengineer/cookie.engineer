
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const doc   = global.document;
		const cache = {};



		/*
		 * HELPERS
		 */

		const create_dummy = (text) => {

			text = text.split('\n').join('<br>');
			text = text.split(' ').join('&nbsp;');

			let element = document.createElement('span');

			element.className = '_magic_';
			element.innerHTML = text;

			return element;

		};

		const before = (node, text) => {

			text = typeof text === 'string' ? text : '';

			if (text !== '') {

				let parent = node.parentNode || null;
				if (parent !== null) {
					parent.insertBefore(create_dummy(text), node);
				}

			}

		};

		const after = (node, text) => {

			text = typeof text === 'string' ? text : '';

			if (text !== '') {

				let parent = node.parentNode || null;
				if (parent !== null) {
					parent.insertBefore(create_dummy(text), node.nextSibling);
				}

			}

		};

		const patch = (node, text1, text2) => {

			text1 = typeof text1 === 'string' ? text1 : '';
			text2 = typeof text2 === 'string' ? text2 : '';

			if (text1 !== '') {
				node.prepend(create_dummy(text1));
			}

			if (text2 !== '') {
				node.append(create_dummy(text2));
			}

		};

		const patch_url = (href) => {

			if (href.startsWith('/')) {
				href = 'https://cookie.engineer/' + href;
			} else if (!href.startsWith('https://') && !href.startsWith('http://')) {
				href = 'https://cookie.engineer/' + href;
			}

			return href;

		};

		const filter = (node) => {

			if (node.nodeName === '#text') {
				node.parentNode.removeChild(node);
			}

		};



		/*
		 * IMPLEMENTATION
		 */

		cache.a        = Array.from(doc.querySelectorAll('article a, section > div a'));
		cache.article  = Array.from(doc.querySelectorAll('section article'));
		cache.b        = Array.from(doc.querySelectorAll('article b'));
		cache.button   = Array.from(doc.querySelectorAll('article button'));
		cache.code     = Array.from(doc.querySelectorAll('article code'));
		cache.del      = Array.from(doc.querySelectorAll('article del, section del'));
		cache.em       = Array.from(doc.querySelectorAll('article em'));
		cache.figure   = Array.from(doc.querySelectorAll('section div ~ figure'));
		cache.footer   = Array.from(doc.querySelectorAll('footer'));
		cache.h1       = Array.from(doc.querySelectorAll('section h1'));
		cache.h2       = Array.from(doc.querySelectorAll('section h2'));
		cache.h3       = Array.from(doc.querySelectorAll('section h3'));
		cache.input    = Array.from(doc.querySelectorAll('article input, article textarea'));
		cache.img      = Array.from(doc.querySelectorAll('article img'));
		cache.ol       = Array.from(doc.querySelectorAll('article ol'));
		cache.ol_li    = Array.from(doc.querySelectorAll('article ol li'));
		cache.pre      = Array.from(doc.querySelectorAll('article pre'));
		cache.progress = Array.from(doc.querySelectorAll('article progress'));
		cache.select   = Array.from(doc.querySelectorAll('article select'));
		cache.ul       = Array.from(doc.querySelectorAll('article ul'));
		cache.ul_li    = Array.from(doc.querySelectorAll('article ul li'));


		cache.h1.forEach((h1)             => patch(h1,        '\n\n# ', '\n\n'));
		cache.h2.forEach((h1)             => patch(h1,        '\n## ', '\n\n'));
		cache.h3.forEach((h3)             => patch(h3,        '\n### ', '\n\n'));
		cache.b.forEach((b)               => patch(b,         '**', '**'));
		cache.code.forEach((code)         => patch(code,      '`', '`'));
		cache.del.forEach((del)           => patch(del,       '~', '~'));
		cache.em.forEach((em)             => patch(em,        '*', '*'));
		cache.footer.forEach((footer)     => patch(footer,    '\n\n\n# Footer.\n\n', ''));
		cache.figure.forEach((figure)     => patch(figure,    '', '\n\n'));
		cache.pre.forEach((pre)           => patch(pre,       '\n```' + pre.className + '\n', '```'));
		cache.progress.forEach((progress) => before(progress, '\n' + progress.getAttribute('value') + '% - ' + progress.getAttribute('data-label'), '\n\n'));
		cache.ul.forEach((ul)             => patch(ul,        '\n'));
		cache.ul_li.forEach((li)          => patch(li,        '- ', '\n'));
		cache.ol.forEach((ol)             => patch(ol,        '\n'));
		cache.ol_li.forEach((li, num)     => patch(li,        (num + 1) + '. ', '\n'));

		cache.a.forEach((a) => {

			let img = a.querySelector('img') || null;
			if (img === null) {

				let text = (a.innerText || a.innerHTML).trim();
				let href = patch_url(a.getAttribute('href').trim());

				if (text !== '' && href !== '') {
					patch(a, '[', '](' + href + ')');
				} else if (href !== '') {
					patch(a, '[' + href.split('/').pop() + '](' + href + ')');
				}

			}

		});

		cache.article.forEach((article) => {

			let div = article.querySelector('div');
			if (div !== null) {

				let names = article.className.split('-').filter((v) => v !== '');
				if (names.length > 0) {

					let ingredients = names.map((v) => v.charAt(0).toUpperCase() + v.substr(1));
					if (ingredients.length > 0) {
						patch(div, 'Ingredients: ' + ingredients.join(', ') + '\n');
					}

				}

			}

		});

		cache.button.forEach((button) => {

			before(button, '?{');
			after(button, '}');

		});

		cache.img.forEach((img) => {

			let has_link = img.parentNode.tagName.toLowerCase() === 'a';
			if (has_link === true) {

				let alt = img.getAttribute('alt') || '';
				let src = img.getAttribute('src') || '';

				if (alt !== '') {
					before(img, '![');
					after(img, '](' + patch_url(src) + ')');
				} else if (src !== '') {
					before(img, '![' + patch_url(src) + '](');
					after(img, ')');
				}

			} else {

				let alt = img.getAttribute('alt') || '';
				let src = img.getAttribute('src') || '';

				if (alt !== '') {
					before(img, '![');
					after(img, '](' + patch_url(src) + ')');
				} else if (src !== '') {
					before(img, '![');
					after(img, '](' + patch_url(src) + ')');
				}

			}

		});

		cache.input.forEach((input) => {

			let type  = input.getAttribute('type') || 'text';
			let name  = input.getAttribute('name');
			let value = input.value || '';

			if (type === 'checkbox') {
				value = input.checked === true ? 'on' : 'off';
			}

			if (value === '') {
				value = input.placeholder;
			}

			before(input, '?{' + type + ' ' + name + '}(' + value + ')');

		});

		cache.select.forEach((select) => {

			let name    = select.getAttribute('name');
			let options = Array.from(select.querySelectorAll('option'));
			let option  = options.find((o) => o.selected === true) || null;
			let value   = '';

			if (option !== null) {
				value = option.value;
			}

			if (value === '') {
				value = option.innerText;
			}

			before(select, '?{select ' + name + '}(' + value + ')\n');

		});



		/*
		 * XXX: HACKS AND FIXES
		 */


		((section) => {

			if (section !== null) {

				let div = section.querySelector('div#about-socialize');
				if (div !== null) {
					let fix = doc.createElement('b');
					fix.className = '_magic_';
					fix.innerHTML = 'Socialize Me.';
					patch(fix, '\n# ', '\n');
					div.insertBefore(fix, div.children[0]);
				}

				Array.from(section.querySelectorAll('div a')).forEach((fix) => before(fix, '\n'));
				Array.from(section.querySelectorAll('article:nth-of-type(2)')).forEach((fix) => before(fix, '\n'));

			}

		})(doc.querySelector('section#about'));

		((section) => {

			if (section !== null) {

				let list = section.querySelector('fieldset#search-form ul');
				if (list !== null) {
					Array.from(list.childNodes).forEach((node) => filter(node));
					patch(list, '', '\n');
				}

			}

		})(doc.querySelector('section#search'));

		((section) => {

			if (section !== null) {

				Array.from(section.querySelectorAll('img')).map((img) => {
					return img.nextSibling !== null ? img.nextSibling : null;
				}).filter((node) => {
					return node !== null;
				}).forEach((fix) => {
					after(fix, '\n\n');
				});

				Array.from(section.querySelectorAll('ul')).map((fix) => after(fix, '\n'));

			}

		})(doc.querySelector('section.article'));

	}, true);

})(typeof window !== 'undefined' ? window : this);

