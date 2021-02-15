
(function(global) {

	const notify = (message) => {

		let list = global.document.querySelector('#crypto ul');
		if (list !== null) {

			let item = global.document.createElement('li');

			item.innerHTML = message;

			list.appendChild(item);

			setTimeout(() => {
				item.setAttribute('data-show', true);
			}, 100);

		}

	};

	global.addEventListener('DOMContentLoaded', () => {

		const crypto  = global.crypto;
		const element = global.document.querySelector('#crypto input[type="password"]');
		const ENCODER = new TextEncoder();
		const DECODER = new TextDecoder();



		if (global.crypto !== undefined) {
			notify('Web Crypto API initialized.');
			element.removeAttribute('disabled');
		} else {
			notify('Web Crypto API not available!');
			element.setAttribute('disabled', true);
		}



		const digest = async (password) => {

			let temp   = await crypto.subtle.digest('SHA-256', ENCODER.encode(password));
			let digest = new Uint8Array(temp);

			let str = '';

			for (let d = 0, dl = digest.byteLength; d < dl; d++) {
				str += String.fromCharCode(digest[d]);
			}

			let hex = '';

			for (let s = 0; s < str.length; s++) {

				let val = str.charCodeAt(s).toString(16);
				if (val.length < 2) {
					val = '0' + val;
				}

				hex += val;

			}

			return hex;

		};

		const decrypt = async (buffer, password) => {

			let salt    = buffer.slice( 0, 16);
			let iv      = buffer.slice(16, 16 + 12);
			let pw_key  = await crypto.subtle.importKey('raw', ENCODER.encode(password), 'PBKDF2', false, [ 'deriveKey' ]);
			let aes_key = await crypto.subtle.deriveKey({
				name:       'PBKDF2',
				salt:       salt,
				iterations: 250000,
				hash:       'SHA-256'
			}, pw_key, {
				name:   'AES-GCM',
				length: 256
			}, false, [ 'decrypt' ]);

			let content = await crypto.subtle.decrypt({
				name: 'AES-GCM',
				iv:   iv
			}, aes_key, buffer.slice(16 + 12));

			return DECODER.decode(content);

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



		element.addEventListener('blur', async () => {

			let password = element.value.trim();
			if (password.length > 3) {

				let filename = await digest(password);

				notify('Downloading "' + filename + '.cv" ...');

				let xhr = new XMLHttpRequest();

				xhr.open('GET', '/cv/source/' + filename + '.cv');
				xhr.responseType = 'arraybuffer';

				xhr.onerror = () => {
					notify('Encrypted CV not found.');
					notify('Password wrong or deprecated.');
				};

				xhr.onload = async () => {

					let decrypted = await decrypt(xhr.response, password);
					if (decrypted.length > 0) {

						if (
							decrypted.includes('<section id="about-me">')
							|| decrypted.includes('<section id="employers">')
							|| decrypted.includes('<section id="education">')
						) {

							notify('Encrypted CV found.');
							notify('Password correct.');

							notify('Decrypting CV ...');

							replace('about-me',  decrypted);
							replace('employers', decrypted);
							replace('education', decrypted);

							notify('Done. H4v3 fun :)');


							setTimeout(() => {

								let wrapper = global.document.querySelector('#crypto');
								if (wrapper !== null) {
									wrapper.parentNode.removeChild(wrapper);
								}

							}, 1000);

						}

					}

				};

				xhr.send();

			}

		});

	});

})(typeof window !== 'undefined' ? window : this);

