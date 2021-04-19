
let IMAGE = null;

(function() {

	let img = new Image();

	img.onload = function() {
		IMAGE = this;
	};

	img.src = './source/Goal.png';

})();



const Goal = function(data) {

	this.x = 0;
	this.y = 0;

	this.alive    = true;
	this.width    = 40;
	this.height   = 256;
	this.velocity = 3;

	if (data instanceof Object) {
		Object.assign(this, data);
	}

};


Goal.prototype = {

	update: function(/* game */) {

		this.x -= this.velocity;


		let x     = this.x;
		let width = this.width;


		if (x + width < 0) {
			this.alive = false;
		}

	},

	render: function(context) {

		if (IMAGE !== null) {

			context.drawImage(
				IMAGE,
				this.x - 1 / 2 * this.width,
				this.y - 1 / 2 * this.height,
				this.width,
				this.height
			);

			/*
			context.strokeStyle = '#4dadd4';
			context.strokeRect(
				this.x - 1/2 * this.width,
				this.y - 1/2 * this.height,
				this.width,
				this.height
			);
			*/

		}

	}

};



export { Goal };

