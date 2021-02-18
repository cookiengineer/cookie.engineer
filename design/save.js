
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const doc  = global.document;
		const save = doc.querySelector('dialog#save');



		/*
		 * HELPERS
		 */

		const show_dialog = () => {
			save.setAttribute('open', 'true');
		};

		const hide_dialog = () => {
			save.removeAttribute('open');
		};


		if (save !== null) {

			let button = save.querySelector('button');
			if (button !== null) {
				button.onclick = () => hide_dialog();
			}

			save.addEventListener('click', (event) => {

				if (event.target === save) {

					let is_open = save.getAttribute('open');
					if (is_open === 'true') {
						hide_dialog();
					}

				}

			}, true);

			doc.addEventListener('keydown', (event) => {

				let ctrl = event.ctrlKey === true;
				let key  = event.key || '';

				if (ctrl === true && key === 's') {

					show_dialog();

					event.stopPropagation();
					event.preventDefault();

				} else if (key === 'Escape') {

					let is_open = save.getAttribute('open');
					if (is_open === 'true') {
						hide_dialog();
					}

				}

			}, true);

		}

	}, true);

})(typeof window !== 'undefined' ? window : this);

