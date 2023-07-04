$.extend(z, {

	css: (function() {

		function detectCSS(property, value, replace) {

			// khtml is last one, because it's still supported by webkit -_- legacy shit.
			var vendors = 'Moz ms O Webkit khtml'.split(' '),
				element = document.createElement('notknownbybrowser'),
				v_prop, v, l;

			if (!property.match(/-/)) { // transition -> Transition -> WebkitTransition
				v_prop  = property.charAt(0).toUpperCase() + property.substr(1);
			} else { // Camelize the property

				var x = property.split(/-/);
				v_prop = '';
				for (var i in x) {
					v_prop += x[i].charAt(0).toUpperCase() + x[i].substr(1);
				}

				// update the property
				property = v_prop.charAt(0).toLowerCase() + v_prop.substr(1);

			}

			// only check property support
			if (!value) {

				// native support
				if (element.style[property] !== undefined) {
					return property;
				}

				// vendor support
				for (v = 0, l = vendors.length; v < l; v++) {
					if (element.style[vendors[v] + v_prop] !== undefined) {
						return vendors[v] + v_prop;
					}
				}

			// check detailed support
			} else {

				// TODO: Hacky for now, but still cool, dude =)
				var syntax = value;
				if (replace && replace[0]) {
					value = value.replace(/%1%/, replace[0]);
				}
				if (replace && replace[1]) {
					value = value.replace(/%2%/, replace[1]);
				}

				// native support
				//element.style[property] = value;
				if (element.style[property] !== undefined) {
					element.style[property] = value;
					if (element.style[property].length) {
						return [ property, syntax ];
					}
				}

				// vendor support
				for (v = 0, l = vendors.length; v < l; v++) {

					// native property, vendor value
					if (element.style[property] !== undefined) {
						element.style[property] = '-' + vendors[v].toLowerCase() + '-' + value;
						if (element.style[property]) {
							return [ property, '-' + vendors[v].toLowerCase() + '-' + syntax ];
						}
					}

					// vendor property, native value
					if (element.style[vendors[v] + v_prop] !== undefined) {
						element.style[vendors[v] + v_prop] = value;
						if (element.style[vendors[v] + v_prop]) {
							return [ vendors[v] + v_prop, value ];
						}
					}

					// vendor property, vendor value
					if (element.style[vendors[v] + v_prop] !== undefined) {
						element.style[vendors[v] + v_prop] = '-' + vendors[v].toLowerCase() + '-' + value;
						if (element.style[vendors[v] + v_prop]) {
							return [ vendors[v] + v_prop, '-' + vendors[v].toLowerCase() + '-' + syntax ];
						}
					}

				}

			}

		}


		var element = document.createElement('notknownbybrowser');

		return {
			transform: detectCSS('transform'),
			transform3d: detectCSS('perspective'),
			gradient: {
				linear: ( // check for both syntaxes of gradients
					detectCSS('background-image', 'gradient(linear, left top, right bottom, from(%1%), to(%2%))', [ '#000', 'white' ])
					|| detectCSS('background-image', 'linear-gradient(left top, %1%, %2%)', [ '#000', 'white' ])
				),
				radial: (
					detectCSS('background-image', 'radial-gradient(center, contain, %1%, %2%)', [ '#000', 'white'])
				)
			}
		};

	})(),

	requestAnimationFrame: (function() {
		return (window.requestAnimationFrame || window.msRequestAnimationFrame || window.webkitRequestAnimationFrame || window.mozRequestAnimationFrame || function(callback, element) {
			window.setTimeout(callback, 1000 / 60);
		});
	})(),

	updateUIFromOption: function(key, val) {

		var elements = document.querySelectorAll('*[data-key="' + key + '"]');

		for (var e = 0, l = elements.length; e < l; e++) {
			var element = elements[e];

			if (element.type === 'radio') {
				element.checked = element.getAttribute('data-val') === val;

			} else if (element.type === 'range') {

				if (typeof val === 'number') {
					element.setAttribute('value', val);
				} else if (typeof val === 'string') {
					element.setAttribute('value', val.match(/\./) ? parseFloat(val) : parseInt(val, 10));
				}

				var info = document.querySelector(element.getAttribute('data-info')),
					value = element.value.match(/\./) ? element.value.substr(0, 3) : element.value;

				if (info && value) {
					info.innerText = value;
				}
			}

		}

	},

	updateOptionsFromUI: function() {

		var elements = document.querySelectorAll('input'),
			newOptions = {};
		for (var e = 0, l = elements.length; e < l; e++) {

			var element = elements[e],
				key = element.getAttribute('data-key'),
				val;

			val = undefined;

			if (element.type === 'radio' && element.checked) {
				val = element.getAttribute('data-val') || element.value;
			} else if (element.type === 'range') {
				val = element.getAttribute('data-val') || element.value;
			}


			if (key !== undefined && val !== undefined && Benchmark.options[key] !== val) {

				// Number
				if (!isNaN(parseInt(val, 10))) {
					val = parseInt(val, 10);
				} else if (val.match(/\./)) {
					val = parseFloat(val).toPrecision(2);
				}

				newOptions[key] = val;

			}

		}

		// update benchmark options
		Benchmark.setOptions(newOptions);

		for (var s in newOptions) {
			z.updateUIFromOption(s, newOptions[s]);
		}

		// update the location hash now.
		Benchmark.updateHash();

		return true;

	}

});
