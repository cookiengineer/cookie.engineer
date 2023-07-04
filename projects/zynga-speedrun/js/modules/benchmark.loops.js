$.extend(z.Benchmark.prototype, {

	initLoops: function() {


		// required for _contextLoop
		this.__position = { x: 0, y: 0, z: 0 };
		this.__zIndex = 1;
		this.__speed = { x: Math.random() / 2, y: Math.random() / 2, z: Math.random() / 2 };
		this.__direction = {
			x: (Math.random() > 0.5) ? 1 : -1,
			y: (Math.random() > 0.5) ? 1 : -1,
			z: (Math.random() > 0.5) ? 1 : -1
		};

		this.__degree = { x: 0, y: 0, z: 0 };
		this.__perspective = 'perspective(' + parseInt(this.options.width, 10) * parseInt(this.options.height, 10) + ')';

		// required for _paintsLoop
		this._paintCounter = document.createElement('div');
		this._paintCounter.style.position = 'absolute';
		document.body.appendChild(this._paintCounter);

	},

	/*
	 * This function is the render loop which will request the next animation frame if rendering and calculating the fps rate was done.
	 *
	 * IMPORTANT: Keep this loop as simple as possible. Otherwise there are
	 * a couple of MEM-Leaks across all Browsers.
	 *
	 */

	_renderLoop: function() {

		if (this._running) {

			var self = this,
				nodebackground = this.options.nodebackground,
				time = +new Date();

			// The statistics (pps / fps)
			this._ppsLoop();

			// The context stuff
			this._contextLoop();

			// rerender
			for (var d = 0, l = this.dynamicNodes.length; d < l; d++) {

				this.setPosition(this.dynamicNodes[d]);

				// only update the sprite animation if requested.
				if (nodebackground === 'sprite' || nodebackground === 'sprite-translate3d') {
					this.setSpritePosition(this.dynamicNodes[d], time);
				}

			}


			this.__lastLoopTime = time;

			// request the next frame
			z.requestAnimationFrame.call(window, function() {
				self._renderLoop();
			}, self.context);

		}

	},

	_contextLoop: function() {

		var context = this.options.context;
		if (context === 'none') {
			return;
		}


		switch(context) {

			case 'zindex':

				this.__zIndex += this.__speed.z;
				this.context.style.zIndex = Math.round(this.__zIndex);

				break;

			case 'rotate':
			case 'rotate3d':

				this.__degree.x += this.__speed.x;
				this.__degree.y += this.__speed.y;
				this.__degree.z += this.__speed.z;

				if (context !== 'rotate3d') {
					this.context.style[z.css.transform] = 'rotateX(' + this.__degree.x + 'deg) rotateY(' + this.__degree.y + 'deg)';
				} else {
					this.context.style[z.css.transform] = this.__perspective + ' rotateX(' + this.__degree.x + 'deg) rotateY(' + this.__degree.y + 'deg) rotateZ(' + this.__degree.z + 'deg)';
				}

				break;

			case 'translate':
			case 'translate3d':

				this.__direction.x = this.__position.x > this.width / 4 ? -1 : (this.__position.x < 0 ? 1 : this.__direction.x);
				this.__position.x += this.__speed.x * this.__direction.x;

				this.__direction.y = this.__position.y > this.height / 4 ? -1 : (this.__position.y < 0 ? 1 : this.__direction.y);
				this.__position.y += this.__speed.y * this.__direction.y;


				this.__direction.z = this.__position.z > this.depth / 4 ? -1 : (this.__position.z < 0 ? 1 : this.__direction.z);
				this.__position.z += this.__speed.z * this.__direction.z;

				if (context !== 'translate3d') {
					this.context.style[z.css.transform] = ' translate(' + this.__position.x + 'px, ' + this.__position.y + 'px)';
				} else {
					this.context.style[z.css.transform] = this.__perspective + ' translate3d(' + this.__position.x + 'px, ' + this.__position.y + 'px, ' + this.__position.z + 'px)';
				}

				break;

		}

	},

	/*
	 * This function is the paints loop and is only there to calculate the paints in the browser window.
	 * De facto it's nearly impossible to calculate the paints, but this function will calculate the paints dependent on
	 * the by-the-renderer calculated offsets of an appended element.
	 */
	_ppsLoop: function() {

		// ALL these properties are CPU-dependent. So they are actually about 3-10 times higher on GPU-acceleration.
		// The browser skips frames, but these frames are available as these properties:
		// this._paintCounter.style.left
		// window.getComputedStyle(this._paintCounter,null).getPropertyValue('left')
		// this._paintCounter.innerHTML
		// this._paintCounter.offsetLeft // and other offset properties


		// calculate paints
		if (this._paintCounter.offsetWidth === this.statistics.paints) {
			this.statistics.paints++;
		}

		// prepare paints for next _ppsLoop
		this._paintCounter.style.width = this.statistics.paints + 'px';


		// update the statistics
		var time = +new Date(),
			fps_diff = time - this.__lastLoopTime,
			pps_diff = time - this.statistics.started;

		this.statistics.fps = ~~(1000 / fps_diff);
		this.statistics.pps = ~~(this.statistics.paints / (pps_diff / 1000));

	}

});
