
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const doc   = global.document;
		const cache = {};



		/*
		 * HELPERS
		 */

		const _create_dummy = (text) => {

			text = text.split('\n').join('<br>');

			let element = document.createElement('span');

			element.className = '_copy_paste_';
			element.innerHTML = text;

			return element;

		};

		const _before = (node, text) => {

			text = typeof text === 'string' ? text : '';

			if (text !== '') {

				let parent = node.parentNode || null;
				if (parent !== null) {
					parent.insertBefore(_create_dummy(text), node);
				}

			}

		};

		const _after = (node, text) => {

			text = typeof text === 'string' ? text : '';

			if (text !== '') {

				let parent = node.parentNode || null;
				if (parent !== null) {
					parent.insertBefore(_create_dummy(text), node.nextSibling);
				}

			}

		};

		const _patch = (node, text1, text2) => {

			text1 = typeof text1 === 'string' ? text1 : '';
			text2 = typeof text2 === 'string' ? text2 : '';

			if (text1 !== '') {
				node.prepend(_create_dummy(text1));
			}

			if (text2 !== '') {
				node.append(_create_dummy(text2));
			}

		};

		const _patch_url = (href) => {

			if (href.startsWith('/')) {
				href = 'https://cookie.engineer/' + href;
			} else if (!href.startsWith('https://') && !href.startsWith('http://')) {
				href = 'https://cookie.engineer/' + href;
			}

			return href;

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
		cache.h3       = Array.from(doc.querySelectorAll('section h3, dialog h3'));
		cache.input    = Array.from(doc.querySelectorAll('article input, article textarea'));
		cache.img      = Array.from(doc.querySelectorAll('article img'));
		cache.ol       = Array.from(doc.querySelectorAll('article ol'));
		cache.ol_li    = Array.from(doc.querySelectorAll('article ol li'));
		cache.pre      = Array.from(doc.querySelectorAll('article pre'));
		cache.progress = Array.from(doc.querySelectorAll('article progress'));
		cache.select   = Array.from(doc.querySelectorAll('article select'));
		cache.ul       = Array.from(doc.querySelectorAll('article ul'));
		cache.ul_li    = Array.from(doc.querySelectorAll('article ul li'));


		cache.h1.forEach((h1)             => _patch(h1,        '\n\n# ', '\n\n'));
		cache.h2.forEach((h1)             => _patch(h1,        '\n## ', '\n\n'));
		cache.h3.forEach((h3)             => _patch(h3,        '\n ### ', h3.querySelector('progress') ? '\n' : '\n\n'));
		cache.b.forEach((b)               => _patch(b,         '**', '**'));
		cache.code.forEach((code)         => _patch(code,      '`', '`'));
		cache.del.forEach((del)           => _patch(del,       '~', '~'));
		cache.em.forEach((em)             => _patch(em,        '*', '*'));
		cache.footer.forEach((footer)     => _patch(footer,    '\n\n\n# Footer.\n\n', ''));
		cache.figure.forEach((figure)     => _patch(figure,    '', '\n\n'));
		cache.pre.forEach((pre)           => _patch(pre,       '\n ```' + pre.className + '\n', '```'));
		cache.progress.forEach((progress) => _before(progress, ': ' + progress.getAttribute('data-label')));
		cache.ul.forEach((ul)             => _patch(ul,        '\n'));
		cache.ul_li.forEach((li)          => _patch(li,        '- '));
		cache.ol.forEach((ol)             => _patch(ol,        '\n'));
		cache.ol_li.forEach((li, num)     => _patch(li,        (num + 1) + '. '));


		cache.a.forEach((a) => {

			let img = a.querySelector('img') || null;
			if (img === null) {

				let text = (a.innerText || a.innerHTML).trim();
				let href = _patch_url(a.getAttribute('href').trim());

				if (text !== '' && href !== '') {
					_patch(a, '[', '](' + href + ')');
				} else if (href !== '') {
					_patch(a, '[' + href.split('/').pop() + '](' + href + ')');
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
						_patch(div, 'Ingredients: ' + ingredients.join(', ') + '\n');
					}

				}

			}

		});

		cache.button.forEach((button) => {

			_before(button, '?{');
			_after(button, '}');

		});

		cache.img.forEach((img) => {

			let has_link = img.parentNode.tagName.toLowerCase() === 'a';
			if (has_link === true) {

				let alt = img.getAttribute('alt') || '';
				let src = img.getAttribute('src') || '';

				if (alt !== '') {
					_before(img, '![');
					_after(img, '](' + _patch_url(src) + ')');
				} else if (src !== '') {
					_before(img, '![' + _patch_url(src) + '](');
					_after(img, ')');
				}

			} else {

				let alt = img.getAttribute('alt') || '';
				let src = img.getAttribute('src') || '';

				if (alt !== '') {
					_before(img, '![');
					_after(img, '](' + _patch_url(src) + ')');
				} else if (src !== '') {
					_before(img, '![');
					_after(img, '](' + _patch_url(src) + ')');
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

			_before(input, '?{' + type + ' ' + name + '}(' + value + ')');

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

			_before(select, '?{select ' + name + '}(' + value + ')\n');

		});



		/*
		 * XXX: HACKS AND FIXES
		 */

		let div = doc.querySelector('#about-me div');
		if (div !== null) {
			let fix = doc.createElement('b');
			fix.className = '_copy_paste_';
			fix.innerHTML = 'Socialize Me.';
			_patch(fix, '\n# ', '\n');
			div.insertBefore(fix, div.children[0]);
		}

		// <b class="_copy_paste_">Socialize Me.</b>
		const _filter_text = (node) => {
			if (node.nodeName === '#text') {
				node.parentNode.removeChild(node);
			}
		};

		Array.from(doc.querySelectorAll('fieldset#search-form input')).forEach((fix) => _before(fix, '\n'));
		Array.from(doc.querySelectorAll('fieldset#contact-form')).forEach((fix) => _before(fix, '\n'));
		Array.from(doc.querySelectorAll('#about-me div a')).forEach((fix) => _before(fix, '\n'));
		Array.from(doc.querySelectorAll('#about-me article:nth-of-type(2)')).forEach((fix) => _before(fix, '\n'));
		Array.from(doc.querySelectorAll('#search article p')).forEach((fix) => _before(fix, '\n'));

		let skills = doc.querySelector('#skills article');
		if (skills !== null) {
			Array.from(skills.childNodes).forEach((node) => _filter_text(node));
		}

		let search = doc.querySelector('fieldset#search-form');
		if (search !== null) {
			Array.from(search.childNodes).forEach((node) => _filter_text(node));
			Array.from(search.querySelector('ul').childNodes).forEach((node) => _filter_text(node));
		}

		let weblog = doc.querySelector('#weblog article');
		if (weblog !== null) {

			Array.from(weblog.querySelectorAll('img')).map((img) => {

				let node = img.nextSibling;
				if (node !== null) {
					return node.nextSibling;
				}

				return null;

			}).filter((node) => node !== null).forEach((node) => {
				_before(node, '\n\n');
			});

		}

	}, true);

})(typeof window !== 'undefined' ? window : this);

