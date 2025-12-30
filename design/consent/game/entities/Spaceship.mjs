
import { GetImage         } from "../../common/image/GetImage.mjs";
import { InterpolateColor } from "../math/InterpolateColor.mjs";

export const Spaceship = function(screen_width, screen_height) {

	this.image = GetImage("Spaceship");

	this.health = 100;
	this.width  = 128;
	this.height = 80;
	this.position = {
		x: 0,
		y: ((screen_height / 2) - this.height - 32) | 0
	};

	this.exhaust_left  = [];
	this.exhaust_right = [];

	for (let e = 0; e < 40; e++) {

		this.exhaust_left.push({
			life: Math.random() * 5.0,
			r:    (1 + Math.random() * 5) | 0,
			x:    (this.position.x - 14 + (Math.random() * 4)) | 0,
			y:    this.position.y + 35,
		});

		this.exhaust_right.push({
			life: Math.random() * 5.0,
			r:    (1 + Math.random() * 5) | 0,
			x:    (this.position.x + 14 - (Math.random() * 4)) | 0,
			y:    this.position.y + 35,
		});

	}

	this.speed = {
		x: 0,
		y: 0
	};
	this.target = {
		x: 0,
		y: 0
	};

};

Spaceship.prototype = {

	CollidesWith: function(entity) {

		if (typeof entity.radius === "number") {

			let closest_x = Math.max(this.position.x, Math.min(entity.position.x, this.position.x + this.width));
			let closest_y = Math.max(this.position.y, Math.min(entity.position.y, this.position.y + this.height));

			let dx = entity.position.x - closest_x;
			let dy = entity.position.y - closest_y;

			return (dx * dx + dy * dy) <= (entity.radius * entity.radius);

		} else if (typeof entity.width === "number" && typeof entity.height === "number") {

			if (this.position.x + this.width / 2 > entity.position.x - entity.width / 2 && this.position.x - this.width / 2 < entity.position.x + entity.width / 2) {

				if (this.position.y + this.height / 2 > entity.position.y - entity.height / 2 && this.position.y - this.height / 2 < entity.position.y + entity.height / 2) {
					return true;
				}

			}

		}

		return false;

	},

	Hit: function(health) {

		health = typeof health === "number" ? health : 1;

		this.health -= health;

		if (this.health < 0) {
			this.health = 0;
		}

	},

	MoveTo: function(x, y) {

		x = typeof x === "number" ? x : this.position.x;
		y = typeof y === "number" ? y : this.position.y;

		if (x > this.position.x) {

			if (x > this.position.x + this.width / 2) {
				this.speed.x = 600;
				this.target.x = x;
			}

		} else if (x < this.position.x) {

			if (x < this.position.x - this.width / 2) {
				this.speed.x = -600;
				this.target.x = x;
			}

		}

		if (y > this.position.y) {

			if (y > this.position.y + this.height / 2) {
				this.speed.y = 600;
				this.target.y = y;
			}

		} else if (y < this.position.y) {

			if (y < this.position.y - this.height / 2) {
				this.speed.y = -600;
				this.target.y = y;
			}

		}

	},

	Render: function(ctx, delta) {

		ctx.globalAlpha = 1.0;

		ctx.drawImage(
			this.image,
			this.position.x - this.width  / 2,
			this.position.y - this.height / 2
		);

		const color1 = [ 183, 233, 235 ]; // #b7 e9 eb
		const color2 = [  17, 101, 193 ];

		for (let e = 0, el = this.exhaust_left.length; e < el; e++) {

			let particle = this.exhaust_left[e];
			let alpha    = particle.life / 3.0;
			let color    = InterpolateColor(color1, color2, 3.0 / particle.life);

			ctx.globalAlpha = alpha;

			ctx.fillStyle = "rgb(" + color[0] + "," + color[1] + "," + color[2] + ")";
			ctx.beginPath();
			ctx.arc(particle.x | 0, particle.y | 0, particle.r, 0, Math.PI * 2);
			ctx.fill();
			ctx.closePath();

			ctx.globalAlpha = 1.0;

		}

		for (let e = 0, el = this.exhaust_right.length; e < el; e++) {

			let particle = this.exhaust_right[e];
			let alpha    = particle.life / 3.0;
			let color    = InterpolateColor(color1, color2, 3.0 / particle.life);

			ctx.globalAlpha = alpha;

			ctx.fillStyle = "rgb(" + color[0] + "," + color[1] + "," + color[2] + ")";
			ctx.beginPath();
			ctx.arc(particle.x | 0, particle.y | 0, particle.r, 0, Math.PI * 2);
			ctx.fill();
			ctx.closePath();

			ctx.globalAlpha = 1.0;

		}

		ctx.globalAlpha = 1.0;

	},

	Reset: function(screen_width, screen_height, callback) {

		callback = typeof callback === "function" ? callback : null;

		this.health = 1;
		this.position.x = 0;
		this.position.y = ((screen_height / 2) + this.height + 64) | 0;

		this.speed.x = 0;
		this.speed.y = -100;

		this.target.x = 0;
		this.target.y = ((screen_height / 2) - (this.height / 2) - 64) | 0;

		let interval = setInterval(() => {

			if (this.health < 100) {
				this.health++;
			}

			if (this.health == 100 && this.position.y === this.target.y) {

				clearInterval(interval);

				if (callback !== null) {
					callback();
				}

			}

		}, 1000 / 60);

	},

	SetHealth: function(health) {

		if (health > 0) {
			this.health = health;
		}

	},

	SetPosition: function(x, y) {

		this.position.x = x;
		this.position.y = y;

		for (let e = 0, el = this.exhaust_left.length; e < el; e++) {

			let particle = this.exhaust_left[e];

			particle.life = Math.random() * 5.0;
			particle.r    = (1 + Math.random() * 5) | 0;
			particle.x    = (this.position.x - 14 + (Math.random() * 4)) | 0;
			particle.y    = this.position.y + 35;

		}

		for (let e = 0, el = this.exhaust_right.length; e < el; e++) {

			let particle = this.exhaust_right[e];

			particle.life = Math.random() * 5.0;
			particle.r    = (1 + Math.random() * 5) | 0;
			particle.x    = (this.position.x + 14 - (Math.random() * 4)) | 0;
			particle.y    = this.position.y + 35;

		}

	},

	Update: function(delta, width, height) {

		let dt = delta / 1000;

		this.position.x = this.position.x + (dt * this.speed.x);
		this.position.y = this.position.y + (dt * this.speed.y);

		if (Math.abs(this.target.x - this.position.x) < this.width / 2) {
			this.target.x = this.position.x;
			this.speed.x = 0;
		}

		if (Math.abs(this.target.y - this.position.y) < this.height / 2) {
			this.target.y = this.position.y;
			this.speed.y = 0;
		}

		for (let e = 0, el = this.exhaust_left.length; e < el; e++) {

			let particle = this.exhaust_left[e];

			particle.life = particle.life - dt;
			particle.y    = particle.y + dt * 60;

			if (particle.life < 0.0 || particle.y >= height) {
				particle.life = Math.random() * 5.0;
				particle.r    = (1 + Math.random() * 5) | 0;
				particle.x    = (this.position.x - 14 + (Math.random() * 4)) | 0;
				particle.y    = this.position.y + 35;
			}

		}

		for (let e = 0, el = this.exhaust_right.length; e < el; e++) {

			let particle = this.exhaust_right[e];

			particle.life = particle.life - dt;
			particle.y    = particle.y + dt * 60;

			if (particle.life < 0.0 || particle.y >= height) {
				particle.life = Math.random() * 5.0;
				particle.r    = (1 + Math.random() * 5) | 0;
				particle.x    = (this.position.x + 14 - (Math.random() * 4)) | 0;
				particle.y    = this.position.y + 35;
			}

		}

	}

};
