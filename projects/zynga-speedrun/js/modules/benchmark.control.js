$.extend(z.Benchmark.prototype, {

	start: function() {

		// width and height caching
		this.width = this.context.offsetWidth;
		this.height = this.context.offsetHeight;

		// create dynamic nodes
		var i, obj;
		for (i = 0; i < this.options.dynamicamount; i++) {
			obj = this._createNode();
			this.dynamicNodes.push(obj);
			this.context.appendChild(obj.node);
			this.runPlugins(obj);
		}

		// create static nodes
		for (i = 0; i < this.options.staticamount; i++) {
			obj = this._createNode();
			this.staticNodes.push(obj);
			this.context.appendChild(obj.node);
			this.runPlugins(obj);

			// initially run setPosition on the static object
			this.setPosition(obj);

		}

		// only update when context was reset
		if (!this._running) {

			this._running = true;
			this.statistics.started = +new Date();

			// initialize the renderLoop only on initialization
			if (!this._initialized) {

				this._initialized = true;
				this.__lastLoopTime = +new Date();
				this._renderLoop();

			}
		}

	},

	stop: function(msg) {

		// stop renderLoop
		this._running = false;

		this.context.style.cssText = 'text-align:center;color:white;background:black';

		// Bug: transforms are not reset via cssText
		this.context.style[z.css.transform] = ' ';

		this.context.innerHTML = 'Benchmark was stopped.<br>' + (msg || '');

	},

	reset: function() {

		// stop renderLoop
		this._running = false;

		// reset DOM representation
		this.context.innerHTML = ' ';
		this.context.style.cssText = '';

		// reset cache
		this.staticNodes = [];
		this.dynamicNodes = [];

		// reset statistics
		this.statistics.paints = 0;

	},

	update: function() {

		if (!this.options.width) {
			this.options.width = this.context.offsetWidth;
		} else {
			this.context.style.width = this.options.width + 'px';
		}

		if (!this.options.height) {
			this.options.height = this.context.offsetHeight;
		} else {
			this.context.style.height = this.options.height + 'px';
		}

	}

});
