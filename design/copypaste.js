
(function(global) {

	global.addEventListener('DOMContentLoaded', _ => {

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

		const _insert = (node, text) => {

			text = typeof text === 'string' ? text : '';


			if (text !== '') {

				let parent = node.parentNode || null;
				if (parent !== null) {
					parent.insertBefore(_create_dummy(text), node);
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

		const _patch_href = (href) => {

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

		cache.h1       = Array.from(doc.querySelectorAll('section h1'));
		cache.h3       = Array.from(doc.querySelectorAll('section h3, dialog h3'));
		cache.a        = Array.from(doc.querySelectorAll('article a, section > div a'));
		cache.article  = Array.from(doc.querySelectorAll('section article'));
		cache.del      = Array.from(doc.querySelectorAll('article del, section del'));
		cache.figure   = Array.from(doc.querySelectorAll('section div ~ figure'));
		cache.footer   = Array.from(doc.querySelectorAll('footer'));
		cache.input    = Array.from(doc.querySelectorAll('article input, article textarea'));
		cache.progress = Array.from(doc.querySelectorAll('article progress'));
		cache.select   = Array.from(doc.querySelectorAll('article select'));


		cache.h1.forEach(h1         => _patch(h1,     '\n\n# ',              '\n\n'));
		cache.h3.forEach(h3         => _patch(h3,     '\n ### ',             h3.querySelector('progress') ? '\n' : '\n\n'));
		cache.del.forEach(del       => _patch(del,    '~',                   '~'));
		cache.footer.forEach(footer => _patch(footer, '\n\n\n# Footer.\n\n', ''));
		cache.figure.forEach(figure => _patch(figure, '',                    '\n\n'));

		cache.progress.forEach(progress => _insert(progress, ': ' + progress.getAttribute('data-label')));


		cache.a.forEach(a => {

			let img  = a.querySelector('img') || null;
			let text = (a.innerText || a.innerHTML).trim();
			let href = _patch_href(a.getAttribute('href').trim());

			if (img !== null) {
				_patch(a, '![' + href.split('/').pop() + '](' + href + ')');
			} else if (text !== '' && href !== '') {
				_patch(a, '![', '](' + href + ')');
			} else if (href !== '') {
				_patch(a, '![' + href.split('/').pop() + '](' + href + ')');
			}

		});

		cache.article.forEach(article => {

			let div = article.querySelector('div');
			if (div !== null) {

				let names = article.className.split('-').filter(v => v !== '');
				if (names.length > 0) {

					let ingredients = names.map(v => v.charAt(0).toUpperCase() + v.substr(1));
					if (ingredients.length > 0) {
						_patch(div, 'Ingredients: ' + ingredients.join(', ') + '\n');
					}

				}

			}

		});

		cache.input.forEach(input => {

			let type  = input.getAttribute('type') || 'text';
			let name  = input.getAttribute('name');
			let value = input.value || '';

			if (type === 'checkbox') {
				value = input.checked === true ? 'on' : 'off';
			}

			if (value === '') {
				value = input.placeholder;
			}

			_insert(input, '?{' + type + ' ' + name + '}(' + value + ')');

		});

		cache.select.forEach(select => {

			let name    = select.getAttribute('name');
			let options = Array.from(select.querySelectorAll('option'));
			let option  = options.find(o => o.selected === true) || null;
			let value   = '';

			if (option !== null) {
				value = option.value;
			}

			if (value === '') {
				value = option.innerText;
			}

			_insert(select, '?{select ' + name + '}(' + value + ')\n');

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

		Array.from(doc.querySelectorAll('fieldset#search-form input')).forEach(fix => _insert(fix, '\n'));
		Array.from(doc.querySelectorAll('fieldset#contact-form')).forEach(fix => _insert(fix, '\n'));
		Array.from(doc.querySelectorAll('#about-me div a')).forEach(fix => _insert(fix, '\n'));
		Array.from(doc.querySelectorAll('#about-me article:nth-of-type(2)')).forEach(fix => _insert(fix, '\n'));
		Array.from(doc.querySelectorAll('#search article p')).forEach(fix => _insert(fix, '\n'));

		Array.from(doc.querySelector('#skills article').childNodes).forEach(node => _filter_text(node));
		Array.from(doc.querySelector('fieldset#search-form').childNodes).forEach(node => _filter_text(node));
		Array.from(doc.querySelector('fieldset#search-form ul').childNodes).forEach(node => _filter_text(node));

	}, true);

})(typeof window !== 'undefined' ? window : this);

