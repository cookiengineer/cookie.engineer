
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const doc    = global.document;
		const menu   = doc.querySelector('header aside#menu');
		const button = doc.querySelector('header aside#menu a#menu-button');
		const items  = Array.from(menu.querySelectorAll('a[href]')).filter((a) => a !== button);
		const links  = Array.from(doc.querySelectorAll('article a')).filter((a) => a.getAttribute('href').startsWith('#'));

		const toc = doc.querySelector('header aside#toc');
		if (toc !== null) {

			Array.from(toc.querySelectorAll('a[href]')).forEach((a) => {
				items.push(a);
			});

		}



		/*
		 * HELPERS
		 */

		const add_state = (element, state) => {

			let states = element.className.trim().split(' ');
			if (states.includes(state) === false) {
				states.push(state);
			}

			element.className = states.join(' ');

		};

		const del_state = (element, state) => {

			let states = element.className.trim().split(' ');
			if (states.includes(state) === true) {
				states.splice(states.indexOf(state), 1);
			}

			element.className = states.join(' ');

		};

		const has_state = (element, state) => {

			let states = element.className.trim().split(' ');
			if (states.includes(state) === true) {
				return true;
			}

			return false;

		};

		const scroll_to_element = (query) => {

			let element = doc.querySelector(query);
			if (element !== null) {

				let type = element.tagName.toLowerCase();
				if (type === 'section') {

					let headline = element.querySelector('h1');
					if (headline !== null) {
						element = headline;
					}

				} else if (type === 'h2' || type === 'h3' || type === 'h4') {
					// Do Nothing
				} else if (type === 'article') {
					// Do Nothing
				}

			}

			if (element !== null) {

				if (element.id !== '') {
					global.location.hash = '#/' + element.id;
				}

				element.scrollIntoView({
					behavior: 'smooth',
					block:    'start',
					inline:   'nearest'
				});

				return true;

			}


			return false;

		};

		const scroll_to_item = (height) => {

			let found      = null;
			let candidates = Array.from(doc.querySelectorAll('section[id], article[id], h1[id], h2[id], h3[id], h4[id]')).map((candidate) => {

				let item = items.find((item) => {

					let id = item.href.split('#/').pop();
					if (id === candidate.id) {
						return true;
					}

					return false;

				}) || null;

				return {
					element: candidate,
					item:    item
				};

			}).filter((candidate) => candidate.item !== null);

			// Find the candidate inside the current viewport
			for (let c = 0; c < candidates.length; c++) {

				let rect1 = candidates[c].element.getBoundingClientRect();
				if (rect1.top > 0 && rect1.top < height / 2) {

					if (found !== null) {

						let rect2 = found.element.getBoundingClientRect();
						if (rect1.top < rect2.top) {
							found = candidates[c];
						}

					} else {
						found = candidates[c];
					}

				}

			}

			// Find the candidate outside the current viewport
			if (found === null) {

				for (let c = 0; c < candidates.length; c++) {

					let rect1 = candidates[c].element.getBoundingClientRect();
					if (rect1.top < height / 2) {

						if (found !== null) {

							let rect2 = found.element.getBoundingClientRect();
							if (rect1.top > rect2.top) {
								found = candidates[c];
							}

						} else {
							found = candidates[c];
						}

					}

				}

			}

			if (found !== null && found.element !== null && found.item !== null) {

				add_state(found.item, 'active');

				return '#/' + found.element.id;

			}

			return null;

		};



		if (menu !== null) {

			if (global.location.hash.startsWith('#/') === true) {

				let result = scroll_to_element('#' + global.location.hash.split('#/').pop());
				if (result === true) {

					let state = has_state(menu, 'open');
					if (state === true) {
						del_state(menu, 'open');
					}

				}

			}

			if (typeof global.scrollY === 'number') {

				setTimeout(() => {

					let offset  = global.scrollY;
					let current = 0;

					global.addEventListener('scroll', () => {
						current = global.scrollY;
					}, true);

					setInterval(() => {

						let delta = current - offset;
						if (delta > 128) {

							del_state(menu, 'open');
							del_state(menu, 'visible');

							if (toc !== null) {
								del_state(toc, 'visible');
							}

							items.forEach((item) => {

								let href = item.getAttribute('href');
								if (href.startsWith('#/')) {
									del_state(item, 'active');
								}

							});

							offset = current;

						} else if (delta < -128) {

							add_state(menu, 'visible');

							if (toc !== null) {
								add_state(toc, 'visible');
							}

							items.forEach((item) => {

								let href = item.getAttribute('href');
								if (href.startsWith('#/')) {
									del_state(item, 'active');
								}

							});

							offset = current;

						}

						if (Math.abs(delta) > 128) {

							setTimeout(() => {

								let height = global.innerHeight || 0;
								let hash   = scroll_to_item(height);

								if (hash !== null) {
									global.location.hash = hash;
								}

							}, 250);

						}

					}, 250);

				}, 1000);

			}

		}

		if (menu !== null && button !== null) {

			button.addEventListener('click', (event) => {

				let state = has_state(menu, 'open');
				if (state === true) {
					del_state(menu, 'open');
				} else {
					add_state(menu, 'open');
				}

				event.preventDefault();
				event.stopPropagation();

			}, true);

		}

		if (items.length > 0) {

			items.forEach((item) => {

				let href = item.getAttribute('href');
				if (href.includes('#') === true) {

					let hash = '#/' + item.getAttribute('href').split('#').pop();
					if (hash === global.location.hash) {
						item.href = hash;
						add_state(item, 'active');
					} else {
						item.href = hash;
					}

					item.onclick = function() {

						let result = scroll_to_element('#' + this.href.split('#/').pop());
						if (result === true) {

							let state = has_state(menu, 'open');
							if (state === true) {
								del_state(menu, 'open');
							}

						}

					};

				} else {

					let path = item.getAttribute('href');
					if (path === global.location.pathname) {
						item.href = path;
						add_state(item, 'active');
					}

				}

			});

		}

		if (links.length > 0) {

			links.forEach((link) => {

				link.href    = '#/' + link.getAttribute('href').split('#').pop();
				link.onclick = function() {
					scroll_to_element('#' + this.href.split('#/').pop());
				};

			});

		}

		setTimeout(() => {

			let tabbable = Array.from(doc.querySelectorAll('a[href], abbr, button, input, select, textarea'));
			if (tabbable.length > 0) {

				tabbable.forEach((element, index) => {
					element.setAttribute('tabindex', index + 1);
				});

			}

		}, 500);

	}, true);

})(typeof window !== 'undefined' ? window : this);

