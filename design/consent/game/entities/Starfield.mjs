
export const Starfield = function(width, height) {

	this.width     = width;
	this.height    = height;
	this.alive     = true;
	this.alpha     = 0.0;
	this.particles = [];
	this.speed     = 30;

	for (let p = 0; p < 300; p++) {
		this.particles.push({
			r: (1 + Math.random() * 3)  | 0,
			x: (Math.random() * width)  | 0,
			y: (Math.random() * height) | 0
		});
	}

};

Starfield.prototype = {

	Render: function(ctx, delta) {

		ctx.globalAlpha = this.alpha;

		// Not necessary, faded in via CSS
		// ctx.fillStyle = "#000000";
		// ctx.fillRect(0, 0, this.width, this.height);

		for (let p = 0, pl = this.particles.length; p < pl; p++) {

			let particle = this.particles[p];

			ctx.fillStyle = "#ffffff";
			ctx.beginPath();
			ctx.arc(particle.x, particle.y, particle.r, 0, Math.PI * 2);
			ctx.fill();
			ctx.closePath();

		}

		ctx.globalAlpha = 1.0;

	},

	ResizeTo: function(width, height) {

		this.width  = width;
		this.height = height;

		for (let p = 0; p < this.particles.length; p++) {

			let particle = this.particles[p];

			particle.x = (Math.random() * width)  | 0;
			particle.y = (Math.random() * height) | 0;

		}

	},

	Update: function(delta, width, height) {

		let dt = delta / 1000;

		if (this.alpha <= 1.0) {

			this.alpha += dt;

			if (this.alpha >= 1.0) {
				this.alpha = 1.0;
			}

		}

		for (let p = 0, pl = this.particles.length; p < pl; p++) {

			let particle = this.particles[p];

			particle.y = particle.y + this.speed * dt;

			if (particle.y >= height) {
				particle.x = (Math.random() * width) | 0;
				particle.y = 0;
			}

		}

	}

};
