
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const doc   = global.document;
		const card  = doc.querySelector('article#card');
		const info  = doc.querySelector('b#card-menu-info');
		const menu  = doc.querySelector('div#card-menu');
		const style = doc.querySelector('style#card-page');
		const text  = {
			h1: doc.querySelector('article#card h1'),
			h2: doc.querySelector('article#card h2'),
			ul: doc.querySelector('article#card ul')
		};

		const data = {
			width:  8.50,
			height: 5.00,
			fonts:  {
				h1: 0.500,
				h2: 0.320,
				ul: 0.275
			}
		};



		/*
		 * HELPERS
		 */

		const _update_fonts = function() {

			if (text.h1 !== null) {
				text.h1.style.fontSize = (data.height / 10.000).toFixed(3) + 'cm';
			}

			if (text.h2 !== null) {
				text.h2.style.fontSize = (data.height / 15.625).toFixed(3) + 'cm';
			}

			if (text.ul !== null) {
				text.ul.style.fontSize = (data.height / 18.180).toFixed(3) + 'cm';
			}

		};

		const _update_page = function() {

			if (style !== null) {

				let sheet = style.sheet;
				let rule  = sheet.rules[0];

				if (rule.cssText.startsWith('@page {')) {
					sheet.deleteRule(0);
					sheet.insertRule('@page { size: ' + data.width + 'cm ' + data.height + 'cm }');
				}

			}

		};

		const _update_width = function(value) {

			let num = parseFloat(value, 10);
			if (Number.isNaN(num) === false) {
				num = num.toFixed(2);
			} else {
				num = null;
			}

			if (num !== null) {

				data.width = num;

				if (card !== null) {
					card.style.width = num + 'cm';
				}

				if (info !== null) {
					info.innerHTML = data.width + ' cm x ' + data.height + ' cm';
				}

				if (menu !== null) {
					menu.style.width = num + 'cm';
				}

				_update_fonts();
				_update_page();

			}

		};

		const _update_height = function(value) {

			let num = parseFloat(value, 10);
			if (Number.isNaN(num) === false) {
				num = num.toFixed(2);
			} else {
				num = null;
			}

			if (num !== null) {

				data.height = num;

				if (card !== null) {
					card.style.height = num + 'cm';
				}

				if (info !== null) {
					info.innerHTML = data.width + ' cm x ' + data.height + ' cm';
				}

				if (menu !== null) {
					menu.style.transform = 'translate(-50%, calc(-100% - ' + (num / 2).toFixed(3) + 'cm - 4px))';
				}

				_update_fonts();
				_update_page();

			}

		};



		/*
		 * IMPLEMENTATIONS
		 */

		if (card !== null && menu !== null && style !== null) {

			menu.className = 'active';


			let width = menu.querySelector('input[name="width"]');
			if (width !== null) {
				width.oninput = () => _update_width(width.value);
			}

			let height = menu.querySelector('input[name="height"]');
			if (height !== null) {
				height.oninput = () => _update_height(height.value);
			}

		}

	}, true);

})(typeof window !== 'undefined' ? window : this);

