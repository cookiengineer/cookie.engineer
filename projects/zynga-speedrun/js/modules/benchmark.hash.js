$.extend(z.Benchmark.prototype, {

	parseHash: function(hash) {

		if (!hash || !hash.length) {
			hash = window.location.hash;
		}

		if (hash.match(/#/)) {
			hash = hash.split(/#/)[1];
		}

		var hashArr = hash.split(','),
			newOptions = {};

		// we got something to parse
		if (hashArr.length) {

			for (var h = 0, l = hashArr.length; h < l; h++) {
				var _tmp = hashArr[h].split('=');
				var key = _tmp[0],
					val = _tmp[1];

				newOptions[key] = !isNaN(parseInt(val, 10)) ? parseInt(val, 10) : val;
			}

		}

		this.setOptions(newOptions);

	},

	getHash: function() {

		var hashArr = [];
		for (var s in this.options) {

			if (this.options[s] !== this.defaults[s]) {
				hashArr.push(s + '=' + this.options[s]);
			}
		}

		return hashArr.join(',');

	},

	updateHash: function() {
		window.location.hash = this.getHash();
	}

});
