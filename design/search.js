
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const doc      = global.document;
		const articles = Array.from(doc.querySelectorAll('#projects article, #talks article, #weblog-articles tbody tr'));
		const avatar   = doc.querySelector('div#search-form-avatar');
		const inputs   = Array.from(doc.querySelectorAll('fieldset#search-form input'));



		/*
		 * HELPERS
		 */

		const _update_avatar = function(search) {

			avatar.className = search.join('-');

			let ingredients = search.map((s) => s.charAt(0).toUpperCase() + s.substr(1));
			if (ingredients.length > 1) {
				avatar.setAttribute('title', 'Ingredients: ' + ingredients.join(', '));
			} else if (ingredients.length === 1) {
				avatar.setAttribute('title', 'Ingredient: ' + ingredients[0]);
			} else {
				avatar.setAttribute('title', 'Ingredients: A teaspoonful of Vacuum with a pinch of Love');
			}

		};

		const _update_articles = function(search) {

			articles.forEach((article) => {

				let categories = article.className.split('-');
				let visible    = categories.find((c) => search.includes(c)) !== undefined;
				if (visible === true) {
					article.setAttribute('data-result', 'true');
				} else {
					article.setAttribute('data-result', 'false');
				}

			});

		};



		/*
		 * IMPLEMENTATION
		 */

		if (avatar !== null && inputs.length > 0) {

			articles.forEach((article) => {

				let headline = article.querySelector('h3');
				if (headline !== null) {

					headline.onclick = function() {

						let result = article.getAttribute('data-result');
						if (result !== 'true') {
							article.setAttribute('data-result', 'true');
						}

					};

					let ingredients = article.className.split('-').map((s) => s.charAt(0).toUpperCase() + s.substr(1));
					if (ingredients.length > 0) {
						headline.setAttribute('title', 'Ingredients: ' + ingredients.join(', '));
					} else if (ingredients.length === 1) {
						headline.setAttribute('title', 'Ingredient: ' + ingredients[0]);
					}

				}

			});

			inputs.forEach((input) => {

				let name = input.getAttribute('name');

				input.setAttribute('title', 'Ingredient: ' + name.charAt(0).toUpperCase() + name.substr(1));

				input.onclick = function() {

					let active = inputs.filter((input) => input.checked === true);
					let search = active.map((input) => input.id.split('-').pop());

					_update_avatar(search);
					_update_articles(search);

				};

			});


			let active = inputs.filter((input) => input.checked === true);
			let search = active.map((input) => input.id.split('-').pop());

			_update_avatar(search);
			_update_articles(search);

		}

	}, true);

})(typeof window !== 'undefined' ? window : this);

