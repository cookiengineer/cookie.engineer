
export const Lazer = function(owner, x, y, speed_x, speed_y, length, health) {

	speed_x = typeof speed_x === "number" ? speed_x : 0;
	speed_y = typeof speed_y === "number" ? speed_y : 0;
	length  = typeof length === "number"  ? length  : 10;
	health  = typeof health === "number"  ? health  : 1;

	this.position = {
		x: x,
		y: y
	};

	this.scale  = 0;
	this.health = health;
	this.width  = 8;
	this.height = length;
	this.owner  = owner;

	this.speed = {
		x: speed_x,
		y: speed_y
	};

	this.angle = Math.atan2(this.speed.y, this.speed.x) * 180 / Math.PI;
	this.angle = (this.angle % 360 + 360) % 360;

};

Lazer.prototype = {

	ClosestTo: function(entity) {

		let delta_x = entity.position.x - this.position.x;
		let delta_y = entity.position.y - this.position.y;
		let rad     = this.angle * Math.PI / 180;
		let cos     = Math.cos(rad);
		let sin     = Math.sin(rad);

		return {
			x:  delta_x * cos + delta_y * sin,
			y: -delta_x * sin + delta_y * cos
		};

	},

	CollidesWith: function(entity) {

		let local      = this.ClosestTo(entity);
		let half_width = this.width / 2;
		let length     = this.scale * this.height;

		if (typeof entity.radius === "number") {

			let ty = Math.max(0, Math.min(length, local.y));
			let dx = local.x - 0;
			let dy = local.y - ty;

			return (dx * dx + dy * dy) <= (entity.radius + half_width) * (entity.radius + half_width);

		} else if (typeof entity.width === "number" && typeof entity.height === "number") {

			// World-space start/end of laser segment
			let rad = this.angle * Math.PI / 180;
			let x1  = this.position.x;
			let y1  = this.position.y;
			let x2  = x1 + Math.cos(rad) * length;
			let y2  = y1 + Math.sin(rad) * length;

			let hw    = entity.width  / 2 + this.width / 2;
			let hh    = entity.height / 2 + this.width / 2;

			// Parametric: P(t) = start + (end-start)*t, t = [0,1]
			let tmin = 0;
			let tmax = 1;

			let dx    = x2 - x1;
			let min_x = entity.position.x - hw;
			let max_x = entity.position.x + hw;

			// X slab
			if (Math.abs(dx) < 0.0000001) {

				// Parallel to x plane
				if (x1 < min_x || x1 > max_x) {
					return false;
				}

			} else {

				let tx1 = (min_x - x1) / dx;
				let tx2 = (max_x - x1) / dx;

				tmin = Math.max(tmin, Math.min(tx1, tx2));
				tmax = Math.min(tmax, Math.max(tx1, tx2));

				if (tmin > tmax) {
					return false;
				}

			}

			// Y slab
			let dy    = y2 - y1;
			let min_y = entity.position.y - hh;
			let max_y = entity.position.y + hh;

			if (Math.abs(dy) < 0.0000001) {

				// Parallel to y plane
				if (y1 < min_y || y1 > max_y) {
					return false;
				}

			} else {

				let ty1 = (min_y - y1) / dy;
				let ty2 = (max_y - y1) / dy;

				tmin = Math.max(tmin, Math.min(ty1, ty2));
				tmax = Math.min(tmax, Math.max(ty1, ty2));

				if (tmin > tmax) {
					return false;
				}

			}

			return tmax >= 0 && tmin <= 1;

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

		let rad    = this.angle * Math.PI / 180;
		let length = this.scale * this.height;

		ctx.save();
		ctx.translate(this.position.x, this.position.y);
		ctx.rotate(rad + Math.PI / 2);
		ctx.globalAlpha = 1.0;
		ctx.fillStyle = "#ff0f5a";
		ctx.fillRect(
			-(this.width / 2),
			0,
			this.width,
			length
		);
		ctx.globalAlpha = 1.0;

		ctx.restore();

	},

	Update: function(delta, width, height) {

		let dt = delta / 1000;

		if (this.scale < 1) {

			this.scale += dt * 4;

			if (this.scale > 1) {
				this.scale = 1;
			}

		}

		this.position.x = this.position.x + (this.speed.x * dt);
		this.position.y = this.position.y + (this.speed.y * dt);

		this.angle = Math.atan2(this.speed.y, this.speed.x) * 180 / Math.PI;
		this.angle = (this.angle % 360 + 360) % 360;

		if (this.position.x < (-width / 2) || this.position.x > (+width / 2)) {
			this.health = 0.0;
		}

		if (this.position.y < (-height / 2) || this.position.y > (+height / 2)) {
			this.health = 0.0;
		}

	},

};
