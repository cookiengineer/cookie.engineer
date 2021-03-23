
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const open_source = global.document.querySelector('section#open-source');



		let xhr = new XMLHttpRequest();

		xhr.open('GET', '../index.html');
		xhr.setRequestHeader('Content-Type', 'text/html');

		xhr.onload = () => {

			let data = xhr.responseText || '';

			let str0 = data.indexOf('<section id="open-source"');
			let str1 = data.indexOf('</section>', str0);

			if (str0 !== -1 && str1 !== -1) {

				let chunk   = data.substr(str0, str1 - str0 + 10);
				let element = global.document.createElement('this-is-a-dummy');

				// XXX: Hacky, but has to be done here to prevent 404s
				chunk = chunk.split('src="projects/').join('src="/projects/');
				chunk = chunk.split('href="projects/').join('href="/projects/');

				element.innerHTML = chunk;

				setTimeout(() => {

					let articles = Array.from(element.querySelectorAll('article'));
					if (articles.length > 0) {

						let placeholder = open_source.querySelector('article');
						if (placeholder !== null) {
							placeholder.parentNode.removeChild(placeholder);
						}

						articles.forEach((article) => {
							open_source.appendChild(article);
						});

					}

				}, 0);

			}

		};

		xhr.send(null);

	});

})(typeof window !== 'undefined' ? window : this);

