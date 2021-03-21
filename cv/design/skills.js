
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const skills = global.document.querySelector('section#skills');



		let xhr = new XMLHttpRequest();

		xhr.open('GET', '../index.html');
		xhr.setRequestHeader('Content-Type', 'text/html');

		xhr.onload = () => {

			let data = xhr.responseText || '';

			let str0 = data.indexOf('<section id="skills"');
			let str1 = data.indexOf('</section>', str0);

			if (str0 !== -1 && str1 !== -1) {

				let chunk   = data.substr(str0, str1 - str0 + 10);
				let element = global.document.createElement('this-is-a-dummy');

				// XXX: Hacky, but has to be done here to prevent 404s
				chunk = chunk.split('src="skills/').join('src="/skills/');
				chunk = chunk.split('href="skills/').join('href="/skills/');

				element.innerHTML = chunk;

				setTimeout(() => {

					let articles = Array.from(element.querySelectorAll('article'));
					if (articles.length > 0) {

						let placeholder = skills.querySelector('article');
						if (placeholder !== null) {
							placeholder.parentNode.removeChild(placeholder);
						}

						articles.forEach((article) => {
							skills.appendChild(article);
						});

					}

				}, 0);

			}

		};

		xhr.send(null);

	});

})(typeof window !== 'undefined' ? window : this);

