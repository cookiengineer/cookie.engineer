
import { GetImage         } from "../../common/image/GetImage.mjs";
import { PlaySoundAt      } from "../../common/sound/PlaySoundAt.mjs";
import { InterpolateOrbit } from "../math/InterpolateOrbit.mjs";
import { Cookie           } from "./Cookie.mjs";
import { Lightning        } from "./Lightning.mjs";

export const CookieEngineer = function(game) {

	this.game = game;

	this.health = 100;
	this.shield = 200;

	this.action = CookieEngineer.Actions.Idle;
	this.events = {
		charge: null,
		fire:   null,
		idle:   Date.now(),
		hit:    Date.now()
	};

	this.invincible = true;
	this.orbiters = [];
	this.radius   = 128;
	this.position = {
		x: 0,
		y: 0
	};
	this.target = {
		x: null,
		y: null
	};

};

CookieEngineer.Actions = {

	// Randomizer
	Idle:              0,
	SpawnCookieShield: 1,
	SpawnCookieWave:   2,
	ChargeLightning:   3,

	// Outside scope of Randomizer
	FireLightning: 4

};

CookieEngineer.Durations = {

	// Randomizer
	Idle:              10000,
	SpawnCookieShield:  3000,
	SpawnCookieWave:    5000,
	ChargeLightning:    1500,

	// Outside scope of Randomizer
	FireLightning: 1000

};

CookieEngineer.prototype = {

	CollidesWith: function(entity) {

		if (this.invincible === true) {
			return false;
		}

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

		if (this.invincible === false) {

			if (this.shield > 0) {

				this.shield -= 1;
				this.events.hit = Date.now();

			} else if (this.health > 0) {

				this.health -= 1;
				this.events.hit = Date.now();

			}

		}

	},

	Reset: function() {

		this.health = 100;
		this.shield = 200;
		this.invincible = true;
		this.orbiters = [];

	},

	SetHealth: function(health) {

		if (health > 0) {
			this.health = health;
		}

	},

	SetInvincible: function(invincible) {

		invincible = typeof invincible === "boolean" ? invincible : false;

		this.invincible = invincible;

	},

	SetShield: function(shield) {

		if (shield > 0) {
			this.shield = shield;
		}

	},

	SetPosition: function(x, y) {

		x = typeof x === "number" ? x : this.position.x;
		y = typeof y === "number" ? y : this.position.y;

		this.position.x = x;
		this.position.y = y;

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

		if (this.action === CookieEngineer.Actions.Idle) {

			if (this.invincible === true) {

				if (this.orbiters.length < 1) {

					this.action      = CookieEngineer.Actions.SpawnCookieShield;
					this.events.idle = Date.now() + CookieEngineer.Durations.SpawnCookieShield;

				}

			} else {

				if (this.orbiters.length < 1) {

					this.action      = CookieEngineer.Actions.SpawnCookieShield;
					this.events.idle = Date.now() + CookieEngineer.Durations.SpawnCookieShield;

				} else if (Date.now() < this.events.hit + 2000) {

					this.action      = CookieEngineer.Actions.ChargeLightning;
					this.events.idle = Date.now() + CookieEngineer.Durations.ChargeLightning;

				} else if (Date.now() > this.events.idle) {

					let action = Math.floor(Math.random() * 4);

					if (action === CookieEngineer.Actions.Idle) {

						this.action      = CookieEngineer.Actions.Idle;
						this.events.idle = Date.now() + CookieEngineer.Durations.Idle;

					} else if (action === CookieEngineer.Actions.ChargeLightning) {

						this.action      = CookieEngineer.Actions.ChargeLightning;
						this.events.idle = Date.now() + CookieEngineer.Durations.ChargeLightning;

					} else if (action === CookieEngineer.Actions.SpawnCookieShield) {

						this.action      = CookieEngineer.Actions.SpawnCookieShield;
						this.events.idle = Date.now() + CookieEngineer.Durations.SpawnCookieShield;

					} else if (action === CookieEngineer.Actions.SpawnCookieWave) {

						this.action      = CookieEngineer.Actions.SpawnCookieWave;
						this.events.idle = Date.now() + CookieEngineer.Durations.SpawnCookieWave;

					}

				}

			}

		} else if (this.action === CookieEngineer.Actions.ChargeLightning) {

			if (this.events.charge === null) {

				// XXX: Give player some time to move
				this.target.x = this.game.player.position.x;
				this.target.y = this.game.player.position.y;

				PlaySoundAt("CookieEngineerCharge", (this.position.x / width) * 2.0 - 1.0);
				this.events.charge = Date.now() + CookieEngineer.Durations.ChargeLightning;

			} else if (Date.now() > this.events.charge) {

				this.events.charge = null;
				this.action        = CookieEngineer.Actions.FireLightning;

			}

		} else if (this.action === CookieEngineer.Actions.FireLightning) {

			if (this.events.fire === null) {

				if (this.target.x !== null && this.target.y !== null) {

					PlaySoundAt("CookieEngineerLightning", (this.position.x / width) * 2.0 - 1.0);

					this.game.Spawn(new Lightning(
						"enemy",
						this.position.x,
						this.position.y,
						this.target.x,
						this.target.y,
						20
					));

				}

				this.events.fire = Date.now() + CookieEngineer.Durations.FireLightning;

			} else if (Date.now() > this.events.fire) {
				this.events.fire = null;
				this.action      = CookieEngineer.Actions.Idle;
			}

		} else if (this.action === CookieEngineer.Actions.SpawnCookieShield) {

			if (this.orbiters.length < 1) {

				if (this.orbiters.length > 0) {

					// Despawn in Game Logic
					for (let o = 0, ol = this.orbiters.length; o < ol; o++) {
						this.game.Despawn(this.orbiters[o]);
					}

					this.orbiters = [];

				}

				InterpolateOrbit(this.position.x, this.position.y, this.radius + 48, 16, (cx, cy, radius, angle) => {

					let cookie = new Cookie();

					cookie.OrbitAround(this, radius, 30, angle);
					cookie.SetPosition(cx, cy);

					this.game.Spawn(cookie);
					this.orbiters.push(cookie);

				});

				this.action = CookieEngineer.Actions.Idle;

			} else {
				this.action = CookieEngineer.Actions.Idle;
			}

		} else if (this.action === CookieEngineer.Actions.SpawnCookieWave) {

			this.target.x = this.game.player.position.x;
			this.target.y = this.game.player.position.y;

			InterpolateOrbit(this.position.x, this.position.y, 32, 4, (cx, cy, radius, angle) => {

				let cookie = new Cookie();

				cookie.SetPosition(cx, cy);
				cookie.MoveTo(this.target.x, this.target.y);

				this.game.Spawn(cookie);

			});

			this.action = CookieEngineer.Actions.Idle;

		} else {
			this.action = CookieEngineer.Actions.Idle;
		}

	},

	Render: function(ctx, delta) {

		// Do Nothing, Avatar is already rendered in DOM

	}

};
