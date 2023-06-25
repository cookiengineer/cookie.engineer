
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const load = (url, callback) => {

			let xhr = new XMLHttpRequest();

			xhr.open('GET', url);
			xhr.setRequestHeader('Content-Type', 'text/html');
			xhr.responseType = 'text';

			xhr.onload = () => {

				let html = xhr.response;
				if (html.length > 0) {

					// XXX: Hacky, but has to be done here to prevent 404s
					html = html.split('src="projects/').join('src="/projects/');
					html = html.split('href="projects/').join('href="/projects/');
					html = html.split('src="skills/').join('src="/skills/');
					html = html.split('href="skills/').join('href="/skills/');
					html = html.split('src="talks/').join('src="/talks/');
					html = html.split('href="talks/').join('href="/talks/');

					callback(html);

				}

			};

			xhr.onerror = () => {
				callback(null);
			};

			xhr.send(null);

		};

		const replace = (section, data) => {

			let str0 = data.indexOf('<section id="' + section + '"');
			let str1 = data.indexOf('</section>', str0);

			let target = global.document.querySelector('section#' + section);
			if (target !== null && str0 !== -1 && str1 !== -1) {

				let chunk   = data.substr(str0, str1 - str0 + 10);
				let element = global.document.createElement('this-is-a-dummy');

				element.innerHTML = chunk;

				setTimeout(() => {

					let elements = Array.from(element.querySelector('section#' + section).children);
					if (elements.length > 0) {

						Array.from(target.children).forEach((node) => {
							target.removeChild(node);
						});

						elements.forEach((element) => {
							target.appendChild(element);
						});

					}

				}, 0);

			}

		};

		let file = global.location.pathname.split('/').pop();
		if (file === 'en.html' || file === 'de.html') {

			load('/index.html', (html) => {
				replace('skills', html);
			});

			load('/projects.html', (html) => {
				replace('open-source', html);
			});

		}

	}, true);

})(typeof window !== 'undefined' ? window : this);

