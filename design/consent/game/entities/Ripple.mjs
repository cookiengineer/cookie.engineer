
export const Ripple = function(x, y) {

	this.life = 1.0;

	this.position = {
		x: x,
		y: y
	};
	this.radius = 10;

};

Ripple.prototype = {

	Render: function(ctx, delta) {

		let color1 = [ 180, 220, 255 ];

		ctx.save();

		ctx.globalCompositeOperation = "lighter";
		ctx.globalAlpha = this.life;
		ctx.lineWidth = 4;
		ctx.strokeStyle = "rgba(" + color1[0] + "," + color1[1] + "," + color1[2] + ", 1)";

		ctx.strokeStyle = "rgb(" + color1[0] + "," + color1[1] + "," + color1[2] + ", 1)";
		ctx.shadowBlur = 15;

		ctx.beginPath();
		ctx.arc(this.position.x, this.position.y, this.radius, 0, Math.PI * 2);
		ctx.stroke();
		ctx.restore();

		ctx.lineWidth = 1;
		ctx.globalAlpha = 1.0;
		ctx.globalCompositeOperation = "source-over";

	},

	Update: function(delta, width, height) {

		let dt = delta / 1000;

		this.radius += 2;
		this.life   -= 2 * dt;

		if (this.life < 0) {
			this.life = 0;
		}

	}

};
