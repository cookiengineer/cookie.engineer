
import { GetImage } from "../../common/image/GetImage.mjs";

export const Cookie = function() {

	this.image = GetImage("Cookie");

	this.alpha  = 0;
	this.health = 5;
	this.radius = 16;
	this.position = {
		x: 0,
		y: 0
	};

	this.orbit = {
		primary: null,
		radius:  0,
		speed:   0,
		angle:   0
	};

	this.speed = {
		x: 0,
		y: 30
	};

};

Cookie.prototype = {

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

	MoveTo: function(x, y) {

		x = typeof x === "number" ? x : this.position.x;
		y = typeof y === "number" ? y : this.position.y;

		let dx   = x - this.position.x;
		let dy   = y - this.position.y;
		let dist = Math.hypot(dx, dy);

		if (dist === 0) {
			this.speed.x = 0;
			this.speed.y = 0;
			return;
		}

		this.speed.x = (dx / dist) * 50;
		this.speed.y = (dy / dist) * 50;

	},

	OrbitAround: function(entity, radius, speed, angle) {

		radius = typeof radius === "number" ? radius : null;
		speed  = typeof speed === "number"  ? speed  : 30;
		angle  = typeof angle === "number"  ? angle  : 0;

		if (radius === null) {

			if (typeof entity.radius === "number") {
				radius = entity.radius + 16;
			} else if (typeof entity.width === "number" && typeof entity.height === "number") {
				radius = Math.sqrt(Math.pow(entity.width / 2, 2) + Math.pow(entity.height / 2, 2), 2) + 16;
			}

		}

		if (radius !== null) {
			this.orbit.primary = entity;
			this.orbit.radius  = radius;
			this.orbit.speed   = speed;
			this.orbit.angle   = angle;
		}

	},

	Render: function(ctx, delta) {

		ctx.globalAlpha = this.alpha;
		ctx.drawImage(
			this.image,
			this.position.x - this.radius,
			this.position.y - this.radius
		);
		ctx.globalAlpha = 1.0;

	},

	SetPosition: function(x, y) {

		x = typeof x === "number" ? x : this.position.x;
		y = typeof y === "number" ? y : this.position.y;

		this.position.x = x;
		this.position.y = y;

	},

	Update: function(delta, width, height) {

		let dt = delta / 1000;

		if (this.alpha < 1.0) {

			this.alpha += dt * 2;

			if (this.alpha > 1.0) {
				this.alpha = 1.0;
			}

		}

		if (this.orbit.primary !== null) {

			if (this.orbit.primary.health > 0) {

				this.orbit.angle += this.orbit.speed * dt;
				this.orbit.angle  = (this.orbit.angle % 360 + 360) % 360;

				let rad = this.orbit.angle * (Math.PI / 180);

				this.position.x = this.orbit.primary.position.x + Math.cos(rad) * this.orbit.radius;
				this.position.y = this.orbit.primary.position.y + Math.sin(rad) * this.orbit.radius;

			} else {

				// Explode away from orbit primary

				// 90 degrees further is tangent to current angle
				let rad      = this.orbit.angle * (Math.PI / 180);
				let orbit_vx = Math.cos(rad + Math.PI / 2) * this.orbit.speed;
				let orbit_vy = Math.sin(rad + Math.PI / 2) * this.orbit.speed;

				this.speed.x += orbit_vx;
				this.speed.y += orbit_vy;

				this.orbit.primary = null;

			}

		} else {

			this.position.x += (dt * this.speed.x);
			this.position.y += (dt * this.speed.y);

		}

		if (this.position.y > height) {
			this.health = 0;
		}

	}

};
