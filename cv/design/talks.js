
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const talks = global.document.querySelector('section#talks');



		let xhr = new XMLHttpRequest();

		xhr.open('GET', '../index.html');
		xhr.setRequestHeader('Content-Type', 'text/html');

		xhr.onload = () => {

			let data = xhr.responseText || '';

			let str0 = data.indexOf('<section id="talks"');
			let str1 = data.indexOf('</section>', str0);

			if (str0 !== -1 && str1 !== -1) {

				let chunk   = data.substr(str0, str1 - str0 + 10);
				let element = global.document.createElement('this-is-a-dummy');

				// XXX: Hacky, but has to be done here to prevent 404s
				chunk = chunk.split('src="talks/').join('src="/talks/');
				chunk = chunk.split('href="talks/').join('href="/talks/');

				element.innerHTML = chunk;

				setTimeout(() => {

					let articles = Array.from(element.querySelectorAll('article'));
					if (articles.length > 0) {

						let placeholder = talks.querySelector('article');
						if (placeholder !== null) {
							placeholder.parentNode.removeChild(placeholder);
						}

						articles.forEach((article) => {
							talks.appendChild(article);
						});

					}

				}, 0);

			}

		};

		xhr.send(null);

	});

})(typeof window !== 'undefined' ? window : this);

