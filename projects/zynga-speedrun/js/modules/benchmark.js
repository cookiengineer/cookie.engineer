
var z = z || {};

z.Benchmark = function(options) {

	this.context = document.getElementById('benchmark');
	this.options = $.extend({}, z.Benchmark.prototype.defaults, options);

	// cached nodes
	this.staticNodes = [];
	this.dynamicNodes = [];

	// rendering statistics
	this.statistics = { paints: 0, fps: 0, pps: 0 };

	// initialize the loops if they are available
	this.initLoops && this.initLoops();

	// update the benchmark itself and its settings
	this.update && this.update();

	// init benchmark
	this.start();

};


z.Benchmark.prototype = {

	defaults: {
		context: 'none', // gpu context means containing DOM element
		dynamicamount: 100,
		staticamount: 10,
		opacity: 1,
		position: 'lefttop-xy', // lefttop-xyz, translate-xy, translate-xyz, translate3d-xy, translate3d-xyz, translate3d-xyz2
		maxspeed: 10,
		node: 'div', // div, span, notknown
		nodecontent: 'empty', // empty, text
		nodebackground: 'sprite', // image, image-alpha, sprite, sprite-translate3d
		height: 0,
		width: 0
	},

	// the depth (zIndex or z-axis)
	depth: 10000,

	/*
	 * This function simply creates an object with a node dependent on the actual Benchmark settings
	 * Created nodes will also get a random width and height if they have no background image.
	 */
	_createNode: function() {


		// This will let the nodes be not a nearly-one-dimensional object
		var _width = Math.round(Math.random() * 200),
			_height = parseInt(_width * (0.8 + (Math.random() * 0.4)));


		var object = {
			node: document.createElement(this.options.node),
			width: _width,
			height: _height,

			speed: {
				x: Math.random() * this.options.maxspeed,
				y: Math.random() * this.options.maxspeed,
				z: Math.random() * this.options.maxspeed
			},

			direction: {
				x: (Math.random() > 0.5 ? 1 : -1),
				y: (Math.random() > 0.5 ? 1 : -1),
				z: (Math.random() > 0.5 ? 1 : -1)
			}

		};


		object.node.style.position = 'absolute';
		object.node.style.width = object.width + 'px';
		object.node.style.height = object.height + 'px';

		// randomize initial position
		object.position = {
			x: Math.random() * (this.width - object.width),
			y: Math.random() * (this.height - object.height),
			z: Math.random() * this.depth
		};


		return object;

	},

	/*
	 * This function sets / updates the actual options. The optional third argument prevents an update of the Benchmark or rendering contexts.
	 * @param {Object} options The options object with options[key] = val
	 */
	setOptions: function(diffOptions) {


		// Skip if it's not an object
		if (typeof diffOptions !== 'object') {
			return;
		}

		var newOptions = {},
			str = '';

		for (var o in diffOptions) {
            if (this.options[o] !== diffOptions[o]) {
				str += o+',';
				this.options[o] = newOptions[o] = diffOptions[o];
			}
		}


		if (newOptions.node || str.match(/amount|position|context|maxspeed|width|height/)) {
			this.reset();
		}

		if (str.match(/position/)) {
			this.resetPosition();
		}

		if (str.match(/node/)) {

			var i, l;

			for (i = 0, l = this.staticNodes.length; i < l; i++) {
				this.runPlugins(this.staticNodes[i]);
			}

			for (i = 0, l = this.dynamicNodes.length; i < l; i++) {
				this.runPlugins(this.dynamicNodes[i]);
			}

		}


		// Update the benchmark context which could have been reset by the reset() call.
		this.update();

        // start the benchmark if it was stopped by hooks
		if (!this._running) {
			this.start();
		}


	}

};
