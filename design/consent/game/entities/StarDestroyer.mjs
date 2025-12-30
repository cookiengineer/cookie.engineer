
import { GetImage         } from "../../common/image/GetImage.mjs";
import { PlaySoundAt      } from "../../common/sound/PlaySoundAt.mjs";
import { InterpolateColor } from "../math/InterpolateColor.mjs";
import { InterpolateOrbit } from "../math/InterpolateOrbit.mjs";
import { Cookie           } from "./Cookie.mjs";
import { Lazer            } from "./Lazer.mjs";

export const StarDestroyer = function(game) {

	this.game   = game;
	this.image  = GetImage("StarDestroyer");
	this.cannon = GetImage("StarDestroyerCannon");

	this.health = 100;
	this.shield = 200;

	this.action = StarDestroyer.Actions.Idle;
	this.events = {
		charge: null,
		fire:   null,
		idle:   Date.now(),
		hit:    Date.now()
	};

	this.angle    = 0;
	this.orbiters = [];
	this.radius   = 128 + 28;
	this.position = {
		x: 0,
		y: 0
	};
	this.speed = {
		x: 0,
		y: 30
	};
	this.target = {
		x: null,
		y: null
	};

};

StarDestroyer.Actions = {

	// Randomizer
	Idle:              0,
	RotateCannon:      1,
	SpawnCookieShield: 2,
	SpawnCookieWave:   3,

	// Outside scope of Randomizer
	ChargeCannon: 5,
	FireCannon:   6

};

StarDestroyer.Durations = {

	// Randomizer
	Idle:              3000,
	RotateCannon:      2000,
	SpawnCookieShield: 3000,
	SpawnCookieWave:   5000,

	// Outside scope of Randomizer
	ChargeCannon:      1200,
	FireCannon:        1000

};

StarDestroyer.prototype = {

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

		if (this.shield > 0) {

			this.shield -= 1;
			this.events.hit = Date.now();

		} else if (this.health > 0) {

			this.health -= 1;
			this.events.hit = Date.now();

		}

	},

	Reset: function() {

		this.health = 100;
		this.shield = 200;
		this.orbiters = [];
		this.target.x = null;
		this.target.y = null;

	},

	SetHealth: function(health) {

		if (health > 0) {
			this.health = health;
		}

	},

	SetPosition: function(x, y) {

		x = typeof x === "number" ? x : this.position.x;
		y = typeof y === "number" ? y : this.position.y;

		this.position.x = x;
		this.position.y = y;

	},

	SetShield: function(shield) {

		if (shield > 0) {
			this.shield = shield;
		}

	},

	SetSpeed: function(x, y) {

		x = typeof x === "number" ? x : this.speed.x;
		y = typeof y === "number" ? y : this.speed.y;

		this.speed.x = x;
		this.speed.y = y;

	},

	Update: function(delta, width, height) {

		let dt = delta / 1000;

		for (let o = 0, ol = this.orbiters.length; o < ol; o++) {

			let cookie = this.orbiters[o];

			if (cookie.health <= 0) {
				this.orbiters.splice(o, 1);
				ol--;
				o--;
			}

		}

		if (this.action === StarDestroyer.Actions.Idle) {

			let boundary = (-height / 2) + this.radius + 64;

			if (this.position.y <= boundary) {

				this.angle += 30 * dt;
				this.angle  = (this.angle % 360 + 360) % 360;

				this.position.x += (dt * this.speed.x);
				this.position.y += (dt * this.speed.y);

				this.events.idle = Date.now() + StarDestroyer.Actions.Idle;

			} else {

				this.angle += 30 * dt;
				this.angle  = (this.angle % 360 + 360) % 360;

				if (this.speed.y > 0) {
					this.speed.y = 0;
				}

				if (this.orbiters.length <= 8) {

					this.action      = StarDestroyer.Actions.SpawnCookieShield;
					this.events.idle = Date.now() + StarDestroyer.Durations.SpawnCookieShield;

				} else if (Date.now() < this.events.hit + 2000) {

					this.action      = StarDestroyer.Actions.RotateCannon;
					this.events.idle = Date.now() + StarDestroyer.Durations.RotateCannon;

				} else if (Date.now() > this.events.idle) {

					let action = Math.floor(Math.random() * 4);

					if (action === StarDestroyer.Actions.Idle) {

						this.action      = StarDestroyer.Actions.Idle;
						this.events.idle = Date.now() + StarDestroyer.Durations.Idle;

					} else if (action === StarDestroyer.Actions.RotateCannon) {

						this.action      = StarDestroyer.Actions.RotateCannon;
						this.events.idle = Date.now() + StarDestroyer.Durations.RotateCannon;

					} else if (action === StarDestroyer.Actions.SpawnCookieShield) {

						this.action      = StarDestroyer.Actions.SpawnCookieShield;
						this.events.idle = Date.now() + StarDestroyer.Durations.SpawnCookieShield;

					} else if (action === StarDestroyer.Actions.SpawnCookieWave) {

						this.action      = StarDestroyer.Actions.SpawnCookieWave;
						this.events.idle = Date.now() + StarDestroyer.Durations.SpawnCookieWave;

					}

				}

			}

		} else if (this.action === StarDestroyer.Actions.RotateCannon) {

			// XXX: Give player some time to move
			this.target.x = this.game.player.position.x;
			this.target.y = this.game.player.position.y;

			let dx = this.target.x - this.position.x;
			let dy = this.target.y - this.position.y;

			let target_angle = Math.atan2(dy, dx) * (180 / Math.PI);
			target_angle = (target_angle + 360) % 360;

			let delta_angle = (target_angle - this.angle);
			delta_angle = ((delta_angle + 180) % 360) - 180;

			let rotation_step = 100 * dt; // 100 is rotation speed

			if (Math.abs(delta_angle) <= rotation_step / 2) {

				this.angle = target_angle;
				this.angle = (this.angle % 360 + 360) % 360;

				this.action = StarDestroyer.Actions.ChargeCannon;

			} else {

				this.angle += Math.sign(delta_angle) * rotation_step;
				this.angle  = (this.angle % 360 + 360) % 360;

			}

		} else if (this.action === StarDestroyer.Actions.ChargeCannon) {

			if (this.events.charge === null) {

				PlaySoundAt("StarDestroyerCannonCharge", (this.position.x / (width / 2)) * 2.0 - 1.0);
				this.events.charge = Date.now() + StarDestroyer.Durations.ChargeCannon;

			} else if (Date.now() > this.events.charge) {

				this.events.charge = null;
				this.action        = StarDestroyer.Actions.FireCannon;

			}

		} else if (this.action === StarDestroyer.Actions.FireCannon) {

			if (this.events.fire === null) {

				if (this.target.x !== null && this.target.y !== null) {

					PlaySoundAt("StarDestroyerCannonLazer", (this.position.x / (width / 2)) * 2.0 - 1.0);

					let dx  = (this.position.x - this.target.x);
					let dy  = (this.position.y - this.target.y);
					let len = Math.hypot(dx, dy);
					let rad = (this.angle + 90) * (Math.PI / 180);
					let vx  = (dx / len) * -2000;
					let vy  = (dy / len) * -2000;

					let muzzle_y = -228;

					this.game.Spawn(new Lazer(
						"enemy",
						this.position.x - muzzle_y * Math.sin(rad),
						this.position.y + muzzle_y * Math.cos(rad),
						vx,
						vy,
						500,
						30
					));

				}

				this.events.fire = Date.now() + StarDestroyer.Durations.FireCannon;

			} else if (Date.now() > this.events.fire) {
				this.events.fire = null;
				this.action      = StarDestroyer.Actions.Idle;
			}

		} else if (this.action === StarDestroyer.Actions.SpawnCookieShield) {

			if (this.orbiters.length <= 8) {

				if (this.orbiters.length > 0) {

					// Despawn in Game Logic
					for (let o = 0, ol = this.orbiters.length; o < ol; o++) {
						this.game.Despawn(this.orbiters[o]);
					}

					this.orbiters = [];

				}

				InterpolateOrbit(this.position.x, this.position.y, this.radius + 72, 32, (cx, cy, radius, angle) => {

					let cookie = new Cookie();

					cookie.OrbitAround(this, radius, 30, angle);
					cookie.SetPosition(cx, cy);
					this.game.Spawn(cookie);
					this.orbiters.push(cookie);

				});

				this.action = StarDestroyer.Actions.Idle;

			} else {

				this.action      = StarDestroyer.Actions.SpawnCookieWave;
				this.events.idle = Date.now() + StarDestroyer.Durations.SpawnCookieWave;

			}

		} else if (this.action === StarDestroyer.Actions.SpawnCookieWave) {

			if (this.game.level.id === "secret") {

				this.target.x = this.game.player.position.x;
				this.target.y = this.game.player.position.y;

				InterpolateOrbit(this.position.x, this.position.y, 32, 4, (cx, cy, radius, angle) => {

					let cookie = new Cookie();

					cookie.SetPosition(cx, cy);
					cookie.MoveTo(this.target.x, this.target.y);

					this.game.Spawn(cookie);

				});

				this.action = StarDestroyer.Actions.Idle;

			} else {
				this.action = StarDestroyer.Actions.Idle;
			}

		}

	},

	Render: function(ctx, delta) {

		let shield_percentage = this.shield / 200;

		let f = (Date.now() - this.events.hit) / 200;
		if (f > 1.0) {
			f = 1.0;
		}

		// let color1 = [ 255, 255, 255 ];
		let color1 = [ 180, 220, 255 ];
		let color2 = [ 255,  15,  90 ];
		let color  = InterpolateColor(color1, color2, f);

		ctx.save();
		ctx.translate(this.position.x, this.position.y);

		// Shield Halo
		if (shield_percentage > 0.0) {

			let gradient = ctx.createRadialGradient(
				0, 0, this.radius,
				0, 0, this.radius * 1.3
			);

			gradient.addColorStop(0, "rgba(" + color[0] + "," + color[1] + "," + color[2] + ", 0.3)");
			gradient.addColorStop(1, "rgba(" + color[0] + "," + color[1] + "," + color[2] + ", 0)");

			ctx.globalAlpha = 0.2 + (shield_percentage * 0.8);
			ctx.fillStyle = gradient;
			ctx.beginPath();
			ctx.arc(0, 0, this.radius * 1.3, 0, Math.PI * 2);
			ctx.fill();
			ctx.closePath();

		}

		ctx.rotate((this.angle + 90) * (Math.PI / 180));
		ctx.globalAlpha = 1.0;
		ctx.drawImage(
			this.image,
			0,
			0,
			256,
			256,
			-128,
			-128,
			256,
			256
		);

		// Cannon

		ctx.save();

		if (shield_percentage > 0.0) {
			ctx.shadowColor = "rgba(" + color[0] + "," + color[1] + "," + color[2] + ", 1)";
			ctx.shadowBlur  = (5 + shield_percentage * 15) | 0;
		}

		ctx.translate(0, -160);
		ctx.globalAlpha = 1.0;
		ctx.drawImage(
			this.cannon,
			0,
			0,
			128,
			144,
			-64,
			-72,
			128,
			144
		);
		ctx.restore();

		// Shield Outline
		if (shield_percentage > 0.0) {

			ctx.globalAlpha = 0.2 + (shield_percentage * 0.8);
			ctx.lineWidth = (2 + shield_percentage * 8) | 0;
			ctx.strokeStyle = "rgb(" + color[0] + "," + color[1] + "," + color[2] + ")";
			ctx.shadowColor = "rgba(" + color[0] + "," + color[1] + "," + color[2] + ", 1)";
			ctx.shadowBlur  = (5 + shield_percentage * 15) | 0;

			ctx.beginPath();
			ctx.arc(0, 0, this.radius - (ctx.lineWidth / 2), 0, Math.PI * 2);
			ctx.stroke();
			ctx.closePath();

		}

		// Reset global properties
		ctx.shadowColor = "";
		ctx.shadowBlur = 0;
		ctx.globalAlpha = 1.0;

		ctx.restore();

	}

};
