
export const Lightning = function(owner, origin_x, origin_y, x, y, health) {

	origin_x = typeof origin_x === "number" ? origin_x : x;
	origin_y = typeof origin_y === "number" ? origin_y : y - 32;

	this.origin   = {
		x: origin_x,
		y: origin_y
	};
	this.owner    = owner;
	this.position = {
		x: x,
		y: y
	};

	this.life   = 2.0;
	this.health = health;
	this.radius = 32;

};

Lightning.prototype = {

	CollidesWith: function(entity) {

		if (typeof entity.radius === "number") {

			let dist1 = Math.hypot(this.position.x - entity.position.x, this.position.y - entity.position.y);
			let dist2 = this.radius + entity.radius;

			if (dist1 <= dist2) {
				return true;
			}

		} else if (typeof entity.width === "number" && typeof entity.height === "number") {

			let left   = entity.position.x - entity.width / 2;
			let right  = entity.position.x + entity.width / 2;
			let top    = entity.position.y - entity.height / 2;
			let bottom = entity.position.y + entity.height / 2;

			let closest_x = Math.max(left, Math.min(this.position.x, right));
			let closest_y = Math.max(top, Math.min(this.position.y, bottom));

			let dx   = this.position.x - closest_x;
			let dy   = this.position.y - closest_y;
			let dist = Math.hypot(dx, dy);
			if (dist <= this.radius) {
				return true;
			}

		}

		return false;

	},

	Hit: function() {

		this.health -= 1;

		if (this.health < 0) {
			this.health = 0;
		}

	},

	Render: function(ctx, delta) {

		ctx.globalAlpha = (this.life / 2.0);

		// ctx.beginPath();
		// ctx.arc(this.position.x, this.position.y, this.radius, 0, 2 * Math.PI);
		// ctx.fillStyle = "#ffffff";
		// ctx.fill();
		// ctx.closePath();

		ctx.globalAlpha = (this.life / 2.0);
		ctx.beginPath();
		ctx.moveTo(this.origin.x, this.origin.y);

		for (let s = 1; s < 10; s++) {

			let t = s / 10;
			let x = this.origin.x + (this.position.x - this.origin.x) * t;
			let y = this.origin.y + (this.position.y - this.origin.y) * t;

			let dx = (Math.random() - 0.5) * 40;
			let dy = (Math.random() - 0.5) * 40;

			ctx.lineTo(x + dx, y + dy);

		}

		ctx.lineTo(this.position.x, this.position.y);
		ctx.strokeStyle = "#ffffff";
		ctx.lineWidth = 10;
		ctx.lineCap = "round";
		ctx.stroke();
		ctx.closePath();
		ctx.globalAlpha = 1.0;

		for (let i = 0; i < 10; i++) {

			let angle  = (Math.PI * 2 / 10) * i + Math.random() * 0.3;
			let jitter = (Math.random() - 0.5) * this.radius * 0.25;
			let end_x  = this.position.x + Math.cos(angle) * (this.radius + jitter);
			let end_y  = this.position.y + Math.sin(angle) * (this.radius + jitter);

			ctx.globalAlpha = (this.life / 2.0);
			ctx.beginPath();
			ctx.moveTo(this.position.x, this.position.y);

			for (let s = 1; s < 2; s++) {

				let t = s / 2;
				let x = this.position.x + (end_x - this.position.x) * t;
				let y = this.position.y + (end_y - this.position.y) * t;

				let dx = (Math.random() - 0.5) * 20;
				let dy = (Math.random() - 0.5) * 20;

				ctx.lineTo(x + dx, y + dy);

			}

			ctx.lineTo(end_x, end_y);
			ctx.strokeStyle = "#ffffff";
			ctx.lineWidth = 5;
			ctx.lineCap = "round";
			ctx.stroke();
			ctx.closePath();

		}

	},

	Update: function(delta, width, height) {

		let dt = delta / 1000;

		this.life -= dt;

		if (this.life <= 0.0) {
			this.life   = 0;
			this.health = 0;
		}

	}

};
