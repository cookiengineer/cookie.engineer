
import { GetImage } from "../../common/image/GetImage.mjs";

export const Meteor = function() {

	if (Math.random() >= 0.5) {
		this.image = GetImage("MeteorStone");
	} else {
		this.image = GetImage("MeteorSand");
	}

	this.angle   = (Math.random() * 360) | 0;
	this._sprite = {
		x: Math.floor(Math.random() * 2) * 128,
		y: Math.floor(Math.random() * 2) * 128
	};

	this.health = 10;
	this.radius = 128;
	this.position = {
		x: 0,
		y: 0
	};

	this.speed = {
		x: 0,
		y: 30
	};

};

Meteor.prototype = {

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

		ctx.save();

		ctx.translate(this.position.x, this.position.y);

		ctx.rotate(this.angle * (Math.PI / 180));

		ctx.drawImage(
			this.image,
			this._sprite.x,
			this._sprite.y,
			128,
			128,
			-1 * this.radius,
			-1 * this.radius,
			2 * this.radius,
			2 * this.radius
		);

		ctx.restore();

	},

	SetPosition: function(x, y) {

		x = typeof x === "number" ? x : this.position.x;
		y = typeof y === "number" ? y : this.position.y;

		this.position.x = x;
		this.position.y = y;

	},

	Update: function(delta, width, height) {

		let dt = delta / 1000;

		this.angle += this.speed.y * dt;
		this.angle  = (this.angle % 360 + 360) % 360;

		this.position.x += (dt * this.speed.x);
		this.position.y += (dt * this.speed.y);

	}

};
