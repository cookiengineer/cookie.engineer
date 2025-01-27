
(function(global) {

	const dispatch_profile = () => {

		let profile = global.document.querySelector('#profile');
		if (profile !== null) {

			profile.addEventListener('click', (event) => {

				let avatar = profile.querySelector('#avatar img');

				if (event.target === avatar) {

					[
						profile.querySelector('img'),
						profile.querySelector('figcaption b'),
						profile.querySelector('aside a[href^="mailto:"]')
					].filter((element) => {
						return element !== null;
					}).forEach((element) => {

						if (element.getAttribute('data-src') !== null) {

							let tmp = element.src;

							element.setAttribute('src', element.getAttribute('data-src'));
							element.setAttribute('data-src', tmp);

						}

						if (element.getAttribute('data-html') !== null) {

							let tmp = element.innerHTML;

							element.innerHTML = element.getAttribute('data-html');
							element.setAttribute('data-html', tmp);

						}

						if (element.getAttribute('data-href') !== null) {

							let tmp = element.href;

							element.href = element.getAttribute('data-href');
							element.setAttribute('data-href', tmp);

						}

					});

					event.preventDefault();
					event.stopPropagation();

				}

			});

		}

	};

	const render = (data) => {

		let template = global.document.createElement('template');

		template.innerHTML = data;

		setTimeout(() => {

			let sections = Array.from(template.content.querySelectorAll('section'));

			if (sections.length > 0) {

				sections.forEach((section) => {
					global.document.querySelector('body').appendChild(section);
				});

			}

		}, 0);

	};



	if (global.location.search === "?debug") {

		global.addEventListener('DOMContentLoaded', () => {

			const DECODER = new TextDecoder();

			let xhr = new XMLHttpRequest();

			xhr.open('GET', '/cv/source/DECRYPTED.cv');
			xhr.responseType = 'arraybuffer';

			xhr.onerror = () => {
				console.error('Decrypted CV not found.');
			};

			xhr.onload = async () => {

				let decrypted = await DECODER.decode(xhr.response);
				if (decrypted.length > 0) {

					if (
						decrypted.includes('<section id="profile">')
						|| decrypted.includes('<section id="open-source">')
						|| decrypted.includes('<section id="teaching">')
					) {

						console.error('Decrypted CV found.');

						render(decrypted);

						console.error('Done. H4v3 fun :)');

						setTimeout(() => {

							let wrapper = global.document.querySelector('#crypto');
							if (wrapper !== null) {
								wrapper.parentNode.removeChild(wrapper);
							}

						}, 0);

						setTimeout(() => {
							dispatch_profile();
						}, 100);

					}

				}

			};

			xhr.send();

		});

	} else {

		setTimeout(() => {
			dispatch_profile();
		}, 100)

	}

})(typeof window !== 'undefined' ? window : this);


