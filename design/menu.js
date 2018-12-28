
(function(global) {

	global.addEventListener('DOMContentLoaded', _ => {

		const doc      = global.document;
		const menu     = doc.querySelector('aside#menu');
		const button   = menu.querySelector('button');
		const items    = Array.from(menu.querySelectorAll('a[href]'));
		const links    = Array.from(doc.querySelectorAll('article a')).filter(a => a.getAttribute('href').startsWith('#'));
		const sections = items.map(a => a.href).map(url => {

			let id = url.split('#').pop();
			let element = doc.querySelector('#' + id);
			if (element !== null) {
				return element;
			}

			return null;

		}).filter(section => section !== null);



		/*
		 * HELPERS
		 */

		const _add_state = (element, state) => {

			let states = element.className.trim().split(' ');
			if (states.includes(state) === false) {
				states.push(state);
			}

			element.className = states.join(' ');

		};

		const _del_state = (element, state) => {

			let states = element.className.trim().split(' ');
			if (states.includes(state) === true) {
				states.splice(states.indexOf(state), 1);
			}

			element.className = states.join(' ');

		};

		const _has_state = (element, state) => {

			let states = element.className.trim().split(' ');
			if (states.includes(state) === true) {
				return true;
			}

			return false;

		};

		const _scroll_to_item = (height) => {

			let candidates = sections.slice(0).reverse();
			if (candidates.length > 0) {

				let found = candidates.find(section => {

					let rect = section.getBoundingClientRect();
					if (rect.top > 0 && rect.top < height / 2) {
						return true;
					}

					return false;

				}) || null;

				if (found === null) {
					found = candidates.find(section => {
						return section.getBoundingClientRect().top < 0;
					}) || null;
				}


				if (found !== null) {

					let item = items.find(item => {

						let id = item.href.split('#/').pop();
						if (id === found.id) {
							return true;
						}

						return false;

					}) || null;

					if (item !== null && item.className !== 'active') {

						items.forEach(other => {
							other.className = other === item ? 'active' : '';
						});

						return '#/' + found.id;

					}

				}

			}


			return null;

		};



		if (menu !== null) {

			let scroll_y = global.scrollY || 0;
			if (scroll_y < 160) {
				_del_state(menu, 'visible');
			}

			global.addEventListener('scroll', event => {

				let height = global.innerHeight || 0;
				let offset = global.scrollY     || 0;
				if (offset > 160) {

					_add_state(menu, 'visible');

					let hash = _scroll_to_item(height);
					if (hash !== null) {
						global.location.hash = hash;
					}

				} else if (offset < 160) {

					_del_state(menu, 'open');
					_del_state(menu, 'visible');
					items.forEach(other => other.className = '');

				}

			}, true);

		}

		if (menu !== null && button !== null) {

			button.addEventListener('click', _ => {

				let state = _has_state(menu, 'open');
				if (state === true) {
					_del_state(menu, 'open');
				} else {
					_add_state(menu, 'open');
				}

			}, true);

		}

		if (items.length > 0) {

			items.forEach(item => {

				let href = '#/' + item.getAttribute('href').split('#').pop();
				if (href === global.location.hash) {
					item.className = 'active';
				}

				item.href    = href;
				item.onclick = function() {

					let id      = this.href.split('#/').pop();
					let section = doc.querySelector('#' + id + ' h1');
					if (section !== null) {

						let state = _has_state(menu, 'open');
						if (state === true) {
							_del_state(menu, 'open');
						}

						section.scrollIntoView({
							behavior: 'smooth',
							block:    'center',
							inline:   'nearest'
						});

					}

				};

			});

		}

		if (links.length > 0) {

			links.forEach(link => {

				let href = '#/' + link.getAttribute('href').split('#').pop();

				link.href    = href;
				link.onclick = function() {

					let id      = this.href.split('#/').pop();
					let section = doc.querySelector('#' + id + ' h1');
					if (section !== null) {

						section.scrollIntoView({
							behavior: 'smooth',
							block:    'center',
							inline:   'nearest'
						});

					}

				};

			});

		}

	}, true);

})(typeof window !== 'undefined' ? window : this);

