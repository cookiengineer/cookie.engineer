var FPS;
(function() {

	z.FPS = function() {
		this.context = document.createElement('div');
		this.context.id = 'fpscounter';

		this._init();
	};

	z.FPS.prototype = {

		_init: function() {

			// webkit keyframes for animation
			document.styleSheets[0].insertRule('@-webkit-keyframes fpscounter { from{} to{} }');

			this.context.style.cssText = 'position:absolute;top:0px;left:0px;background:black;color:white;-webkit-animation:fpscounter 16.6ms infinite;';
			document.body.appendChild(this.context);

			this.__lastLoop = +new Date();

			var that = this;
			this.context.addEventListener('webkitAnimationIteration', function(event) {
				that.__loop();
			});

		},

		__loop: function() {

			var now = +new Date(),
				fps = Math.floor(1000 / (now - this.__lastLoop));

			this.log(fps);
			this.__lastLoop = now;

		},

		log: function(value) {
			this.context.innerText = value;
		}

	};

	FPS = new z.FPS();

})();