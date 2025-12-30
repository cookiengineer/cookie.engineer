
import { IsPlaying          } from "../common/music/IsPlaying.mjs";
import { PlayMusic          } from "../common/music/PlayMusic.mjs";
import { StopMusic          } from "../common/music/StopMusic.mjs";
import { PlaySoundAt        } from "../common/sound/PlaySoundAt.mjs";
import { Camera             } from "./components/Camera.mjs";
import { Consent            } from "./components/gui/Consent.mjs";
import { Dialog             } from "./components/gui/Dialog.mjs";
import { Cookie             } from "./entities/Cookie.mjs";
import { CookieEngineer     } from "./entities/CookieEngineer.mjs";
import { Explosion          } from "./entities/Explosion.mjs";
import { Lazer              } from "./entities/Lazer.mjs";
import { Lightning          } from "./entities/Lightning.mjs";
import { Ripple             } from "./entities/Ripple.mjs";
import { Meteor             } from "./entities/Meteor.mjs";
import { Spaceship          } from "./entities/Spaceship.mjs";
import { Starfield          } from "./entities/Starfield.mjs";
import { StarDestroyer      } from "./entities/StarDestroyer.mjs";
import { Status             } from "./entities/gui/Status.mjs";
import { DrawCollisionModel } from "./draw/DrawCollisionModel.mjs";
import { Level as Level1    } from "./levels/Level1.mjs";
import { Level as Level2    } from "./levels/Level2.mjs";
import { Level as Level3    } from "./levels/Level3.mjs";
import { Level as Secret    } from "./levels/Secret.mjs";

export const Game = function(avatar, wrapper, screen_width, screen_height) {

	screen_width  = typeof screen_width === "number"  ? screen_width  : 1280;
	screen_height = typeof screen_height === "number" ? screen_height : 960;

	this.debug   = false;
	this.canvas  = document.createElement("canvas");
	this.context = this.canvas.getContext("2d");
	this.avatar  = avatar;
	this.wrapper = wrapper;


	// Game Entities
	this.entities  = {
		enemies: [],
		lazers:  [],
		effects: []
	};

	// Special Game Entities
	this.player    = new Spaceship(this.canvas.width, this.canvas.height);
	this.starfield = new Starfield(screen_width, screen_height);
	this.camera    = new Camera(this.player);
	this.status    = new Status();

	// Browser UI
	this.consent = new Consent(this, this.avatar);
	this.dialog  = new Dialog(this);

	// State Management
	this.locked  = false;
	this.paused  = false;
	this.running = false;
	this.events  = {
		shoot: {
			timeout: Date.now()
		},
		shake: {
			start:     null,
			duration:  200,
			intensity: 8
		}
	};

	// Level Management
	this.level  = null;
	this.levels = {
		level1: new Level1(this),
		level2: new Level2(this),
		level3: new Level3(this)
	};

	// Level Statistics
	this.statistics = {
		level1: { missed: 0, killed: 0, spawned: 0 },
		level2: { missed: 0, killed: 0, spawned: 0 },
		level3: { missed: 0, killed: 0, spawned: 0 }
	};

	this.__listeners = {
		click: null
	};

	this.__loops = {
		render: null,
		update: null
	};

	this.__time = Date.now();

	this.ResizeTo(screen_width, screen_height);

};

Game.prototype = {

	Despawn: function(entity) {

		if (entity !== undefined && entity !== null) {

			if (entity instanceof Cookie) {

				for (let e = 0, el = this.entities.enemies.length; e < el; e++) {

					if (this.entities.enemies[e] === entity) {
						this.entities.enemies.splice(e, 1);
						el--;
						e--;
						break;
					}

				}

			} else if (entity instanceof Meteor) {

				for (let e = 0, el = this.entities.enemies.length; e < el; e++) {

					if (this.entities.enemies[e] === entity) {
						this.entities.enemies.splice(e, 1);
						el--;
						e--;
						break;
					}

				}

			}

		}

	},

	Destroy: function() {

		if (this.canvas.parentNode !== null) {

			this.canvas.removeEventListener("click", this.__listeners.click);
			this.canvas.parentNode.removeChild(this.canvas);
			this.__listeners.click = null;

		}

		this.avatar.figure.style.display = "block";

		if (this.running === true) {
			this.Stop();
		}

		this.paused  = false;
		this.running = false;

		this.wrapper.removeAttribute("data-mode", "game");

	},

	EnterLevel: function(name, callback) {

		callback = typeof callback === "function" ? callback : null;

		if (this.levels[name] !== undefined) {

			this.entities.enemies = [];

			this.statistics[name].missed  = 0;
			this.statistics[name].killed  = 0;
			this.statistics[name].spawned = 0;

			let world_width  = this.canvas.width;
			let world_height = this.canvas.height;
			if (world_width < 1280) {
				world_width = 1280;
			}

			this.level = this.levels[name];
			this.level.id = name;
			this.level.Reset(world_width, world_height);

			if (this.level.id === "secret") {
				this.avatar.figure.style.display = "none";
			} else {
				this.avatar.figure.style.display = "block";
			}

			if (IsPlaying() === true) {
				StopMusic();
			}

			if (this.avatar.IsSpeaking() === false) {

				this.avatar.Feel("angry");
				this.avatar.Speak("game-" + name, () => {

					if (name === "level1") {

						if (IsPlaying() === false) {
							PlayMusic("game-start", () => {
								PlayMusic("game-level");
							});
						}

					} else if (name === "level2") {

						if (IsPlaying() === false) {
							PlayMusic("game-level");
						}

					} else if (name === "level3") {

						if (IsPlaying() === false) {
							PlayMusic("game-boss");
						}

					} else if (name === "secret") {

						if (IsPlaying() === false) {
							PlayMusic("game-secret");
						}

					}

					if (callback !== null) {
						callback();
					}

				});

			} else {

				if (callback !== null) {
					callback();
				}

			}

		} else {

			console.error("Level \"" + name + "\" not found!");

			this.level = null;

		}

	},

	ExplodeAt: function(x, y) {

		this.entities.effects.push(new Explosion(x, y));
		PlaySoundAt("explosion", (x / (this.canvas.width / 2)) * 2.0 - 1.0);

		this.events.shake.start     = Date.now();
		this.events.shake.duration  = 100 + (Math.random() * 300);
		this.events.shake.intensity = 4 + (Math.random() * 8);

	},

	Init: function() {

		if (this.canvas.parentNode === null) {

			this.wrapper.setAttribute("data-mode", "game");

			this.__listeners.click = (event) => {

				if (this.running === true) {

					let position_x = event.clientX - (this.canvas.width  / 2) + this.camera.position.x;
					let position_y = event.clientY - (this.canvas.height / 2) + this.camera.position.y;

					this.ShootAt(position_x, position_y);
					this.TargetAt(position_x, position_y);

				}

			};

			this.canvas.addEventListener("click", this.__listeners.click, true);
			this.canvas.setAttribute("id", "consent-game");

			this.wrapper.appendChild(this.canvas);

		}

	},

	IsFinished: function() {

		if (this.statistics.level1.spawned > 0 && this.statistics.level1.killed > 0) {

			if (this.statistics.level2.spawned > 0 && this.statistics.level2.killed > 0) {

				if (this.statistics.level3.spawned > 0 && this.statistics.level3.killed > 0) {
					return true;
				}

			}

		}

		return false;

	},

	IsRunning: function() {
		return this.running === true;
	},

	IsPaused: function() {
		return this.paused === true;
	},

	Render: function(delta) {

		let width  = this.canvas.width;
		let height = this.canvas.height;

		this.context.save();
		this.context.clearRect(0, 0, width, height);

		this.starfield.Render(this.context, delta);

		this.context.translate(width / 2, height / 2);
		this.context.translate(-this.camera.position.x, -this.camera.position.y);

		if (this.running === true) {

			if (this.events.shake.start !== null) {

				let shake_x = (Math.random() - 0.5) * this.events.shake.intensity;
				let shake_y = (Math.random() - 0.5) * this.events.shake.intensity;

				this.context.translate(shake_x, shake_y);

			}

			for (let e = 0, el = this.entities.enemies.length; e < el; e++) {

				this.entities.enemies[e].Render(this.context, delta);

				if (this.debug === true) {
					DrawCollisionModel(this.context, delta, this.entities.enemies[e]);
				}

			}

			for (let l = 0, ll = this.entities.lazers.length; l < ll; l++) {

				this.entities.lazers[l].Render(this.context, delta);

				if (this.debug === true) {
					DrawCollisionModel(this.context, delta, this.entities.lazers[l]);
				}

			}

			for (let e = 0, el = this.entities.effects.length; e < el; e++) {
				this.entities.effects[e].Render(this.context, delta);
			}

			this.player.Render(this.context, delta);

			if (this.debug === true) {
				DrawCollisionModel(this.context, delta, this.player);
			}

		}

		this.context.restore();

		this.status.Render(this.context, delta);

	},

	ResizeTo: function(screen_width, screen_height) {

		this.player.MoveTo(0, null);

		this.starfield.ResizeTo(screen_width, screen_height);
		this.status.SetPosition(100 + 16, screen_height - 50 - 16);

		this.camera.screen.width  = screen_width;
		this.camera.screen.height = screen_height;

		this.canvas.width  = screen_width;
		this.canvas.height = screen_height;

		this.canvas.style.width  = screen_width  + "px";
		this.canvas.style.height = screen_height + "px";

	},

	RippleAt: function(x, y) {

		this.entities.effects.push(new Ripple(x, y));
		PlaySoundAt("ripple", (x / (this.canvas.width / 2)) * 2.0 - 1.0);

		this.events.shake.start     = Date.now();
		this.events.shake.duration  = 100 + (Math.random() * 300);
		this.events.shake.intensity = 4 + (Math.random() * 8);

	},

	ShakeAt: function(x, y) {

		this.events.shake.start     = Date.now();
		this.events.shake.duration  = 100 + (Math.random() * 300);
		this.events.shake.intensity = 4 + (Math.random() * 8);

	},

	ShootAt: function(target_x, target_y) {

		if (this.locked === false && Date.now() > this.events.shoot.timeout) {

			if (this.player.position.y > target_y) {

				let dx    = target_x - this.player.position.x;
				let dy    = target_y - (this.player.position.y - 20);
				let angle = Math.atan2(dx, -dy) * (180 / Math.PI);

				// Allow to shoot only within 60 degrees range in both directions
				if (angle >= -60 && angle <= 60) {

					let dx1  = (this.player.position.x - 49) - target_x;
					let dy1  = (this.player.position.y - 20) - target_y;
					let len1 = Math.hypot(dx1, dy1);
					let vx1  = (dx1 / len1) * -200;
					let vy1  = (dy1 / len1) * -200;

					this.entities.lazers.push(new Lazer(
						"player",
						this.player.position.x - 49,
						this.player.position.y - 20,
						vx1,
						vy1,
						20,
						1
					));

					let dx2  = (this.player.position.x + 49) - target_x;
					let dy2  = (this.player.position.y - 20) - target_y;
					let len2 = Math.hypot(dx2, dy2);
					let vx2  = (dx2 / len2) * -200;
					let vy2  = (dy2 / len2) * -200;

					this.entities.lazers.push(new Lazer(
						"player",
						this.player.position.x + 49,
						this.player.position.y - 20,
						vx2,
						vy2,
						20,
						1
					));

					PlaySoundAt("lazer", (this.player.position.x / (this.canvas.width / 2)) * 2.0 - 1.0);
					this.events.shoot.timeout = Date.now() + 175;

				}

			}

		}

	},

	Spawn: function(entity) {

		if (entity !== undefined && entity !== null) {

			if (entity instanceof Explosion) {
				this.entities.effects.push(entity);
			} else if (entity instanceof Ripple) {
				this.entities.effects.push(entity);
			} else if (entity instanceof Lazer) {
				this.entities.lazers.push(entity);
			} else if (entity instanceof Lightning) {
				// Well, is it a lazer? Wave theory says yes
				this.entities.lazers.push(entity);
			} else if (entity instanceof Cookie) {
				this.entities.enemies.push(entity);
				this.statistics[this.level.id].spawned++;
			} else if (entity instanceof Meteor) {
				this.entities.enemies.push(entity);
				this.statistics[this.level.id].spawned++;
			} else if (entity instanceof CookieEngineer) {
				this.entities.enemies.push(entity);
				this.statistics[this.level.id].spawned++;
			} else if (entity instanceof StarDestroyer) {
				this.entities.enemies.push(entity);
				this.statistics[this.level.id].spawned++;
			}

		}

	},

	Start: function(level) {

		typeof level === "string" ? level : "level1";

		this.consent.Hide();
		this.entities.enemies = [];
		this.entities.lazers  = [];
		this.entities.effects = [];

		this.level   = null;
		this.locked  = true;
		this.paused  = false;
		this.running = true;

		if (this.__loops.render === null) {

			this.__time = Date.now();
			this.__loops.render = () => {

				let delta = Date.now() - this.__time;

				if (this.running === true) {
					this.Render(delta);
					requestAnimationFrame(this.__loops.render);
				} else {
					this.__loops.render = null;
				}

			};

			this.__loops.render();

		}

		if (this.__loops.update === null) {

			this.__loops.update = setInterval(() => {

				let now   = Date.now();
				let delta = now - this.__time;

				if (this.running === true) {
					this.Update(delta);
				} else {
					clearInterval(this.__loops.update);
					this.__loops.update = null;
				}

				this.__time = now;

			}, 1000 / 60);

		}

		if (level === "level1") {

			this.player.Reset(this.canvas.width, this.canvas.height, () => {

				this.EnterLevel(level, () => {
					this.locked = false;
				});

			});

		} else {

			if (this.player.position.y < this.canvas.height / 2) {
				this.player.position.y = (this.canvas.height - this.player.height - 32) | 0;
			}

			this.player.MoveTo(0, null);
			this.player.SetHealth(100);
			this.EnterLevel(level, () => {
				this.locked = false;
			});

		}

	},

	Stop: function(show_dialog) {

		typeof show_dialog === "boolean" ? show_dialog : false;

		if (IsPlaying() === true) {
			StopMusic();
		}

		if (show_dialog === true) {

			this.locked  = true;
			this.paused  = true;
			this.running = true;

			this.events.shake.start     = null;
			this.events.shake.duration  = 0;
			this.events.shake.intensity = 0;

			this.dialog.Show(this.statistics);
			PlayMusic("game-over");

		} else {

			this.locked  = true;
			this.paused  = true;
			this.running = false;

		}

	},

	TargetAt: function(position_x, position_y) {

		if (this.locked === false) {

			if (this.player !== null) {

				let canvas_half_width = this.canvas.width / 2;
				let player_half_width = this.player.width / 2;

				if (position_x < (-canvas_half_width + player_half_width)) {
					position_x = -canvas_half_width + player_half_width;
				} else if (position_x > (canvas_half_width - player_half_width)) {
					position_x = canvas_half_width - player_half_width;
				}

				position_y = (this.canvas.height / 2) - (this.player.height / 2) - 64;

				this.player.MoveTo(position_x, position_y);

			}

		}

	},

	UnlockSecret: function() {

		this.levels["secret"]     = new Secret(this);
		this.statistics["secret"] = { missed: 0, killed: 0, spawned: 0 };

		console.log("Congrats! You unlocked the secret Level!");

	},

	Update: function(delta) {

		this.starfield.Update(delta, this.canvas.width, this.canvas.height);
		this.camera.Update(delta, this.canvas.width, this.canvas.height);

		let world_width  = this.canvas.width;
		let world_height = this.canvas.height;

		if (world_width < 1280) {
			world_width = 1280;
		}

		if (this.running === true && this.paused === false) {

			for (let e = 0, el = this.entities.enemies.length; e < el; e++) {

				let enemy  = this.entities.enemies[e];
				let damage = enemy.health;

				enemy.Update(delta, world_width, world_height);

				let destroyed = false;

				if (enemy.CollidesWith(this.player) === true) {

					this.statistics[this.level.id].missed++;

					this.ExplodeAt(enemy.position.x, enemy.position.y);
					destroyed = true;

					this.player.Hit(damage);

				}

				if (destroyed === false) {

					// Make them enemies bounce!
					if (enemy.position.x < (-world_width / 2) && enemy.speed.x < 0) {
						enemy.speed.x = -1 * enemy.speed.x;
					} else if (enemy.position.x > (+world_width / 2) && enemy.speed.x > 0) {
						enemy.speed.x = -1 * enemy.speed.x;
					} else if (enemy.position.y < (-world_height / 2) && enemy.speed.y < 0) {
						enemy.speed.y = -1 * enemy.speed.y;
					} else if (enemy.position.y >= (+world_height / 2) && enemy.speed.y > 0) {

						this.statistics[this.level.id].missed++;

						this.ExplodeAt(enemy.position.x, world_height / 2);
						destroyed = true;

						this.player.Hit(damage);

					}

				}

				if (destroyed === true) {
					this.entities.enemies.splice(e, 1);
					el--;
					e--;
				}

			}

			for (let l = 0, ll = this.entities.lazers.length; l < ll; l++) {

				let lazer = this.entities.lazers[l];

				lazer.Update(delta, world_width, world_height);

				if (lazer.health >= 1.0) {

					if (lazer.owner === "player") {

						for (let e = 0, el = this.entities.enemies.length; e < el; e++) {

							let enemy = this.entities.enemies[e];
							if (lazer.CollidesWith(enemy) === true) {

								// XXX: enemy.shield can be undefined
								if (enemy.shield > 0) {
									this.RippleAt(lazer.position.x, lazer.position.y);
									enemy.Hit();
									lazer.Hit();
								} else if (enemy.health > 0) {
									this.ExplodeAt(lazer.position.x, lazer.position.y);
									enemy.Hit();
									lazer.Hit();
								}

								if (enemy.health <= 0) {
									this.statistics[this.level.id].killed++;
									this.entities.enemies.splice(e, 1);
									el--;
									e--;
								}

							}

						}

					} else if (lazer.owner === "enemy") {

						if (this.player !== null) {

							if (lazer.CollidesWith(this.player) === true) {
								this.ExplodeAt(lazer.position.x, lazer.position.y);
								this.player.Hit();
								lazer.Hit();

							}

						}

					}

				}

				if (lazer.health <= 0.0) {
					this.entities.lazers.splice(l, 1);
					ll--;
					l--;
				}

			}

			for (let e = 0, el = this.entities.effects.length; e < el; e++) {

				let explosion = this.entities.effects[e];

				explosion.Update(delta, world_width, world_height);

				if (explosion.life <= 0) {
					this.entities.effects.splice(e, 1);
					el--;
					e--;
				}

			}

			if (this.player.health <= 0) {

				this.ExplodeAt(this.player.position.x, this.player.position.y);

				if (this.level !== null) {
					this.statistics[this.level.id].missed += this.entities.enemies.length;
					this.Stop(true);
				}

			}

			this.player.Update(delta, world_width, world_height);


			// TODO: This is wrong
			this.status.Update(delta, world_width, world_height);

			if (this.level !== null) {

				this.status.UpdateInfo(
					this.player.health,
					this.level.Progress(),
				);

			} else {

				this.status.UpdateInfo(
					this.player.health,
					0.0
				);

			}

			if (this.events.shake.start !== null) {

				if (Date.now() > this.events.shake.start + this.events.shake.duration) {
					this.events.shake.start     = null;
					this.events.shake.duration  = 0;
					this.events.shake.intensity = 0;
				}

			}

			if (this.entities.enemies.length === 0) {

				if (this.level !== null) {

					if (this.level.id === "level1") {
						this.EnterLevel("level2");
					} else if (this.level.id === "level2") {
						this.EnterLevel("level3");
					} else if (this.level.id === "level3") {

						if (this.levels["secret"] !== undefined) {
							this.EnterLevel("secret");
						} else {
							this.paused = true;
							this.Stop(true);
						}

					}

				}

			}

		}

	}

};
