
import { Cookie          } from "../entities/Cookie.mjs";
import { CookieEngineer  } from "../entities/CookieEngineer.mjs";
import { StarDestroyer   } from "../entities/StarDestroyer.mjs";
import { InterpolateLine } from "../math/InterpolateLine.mjs";

export const Level = function(game) {

	this.id   = "secret";
	this.game = game;

	// Accessed by the Game's Update Loop
	this.enemies = 1 + 1; // 32 orbiting shield cookies
	this.boss1   = new CookieEngineer(this.game);
	this.boss2   = new StarDestroyer(this.game);

};

Level.prototype = {

	Progress: function() {

		if (this.boss1.health >= 0 && this.boss1.position.y >= 0) {

			let boss1_percentage   = (this.boss1.shield + this.boss1.health) / 300 * 100;
			let boss2_percentage   = (this.boss2.shield + this.boss2.health) / 300 * 100;
			let enemies_percentage = 0.0;

			if (this.game.entities.enemies.length > this.enemies) {
				enemies_percentage = 0.0;
			} else if (this.game.entities.enemies.length < this.enemies) {
				enemies_percentage = (this.game.entities.enemies.length / this.enemies * 100);
			}

			return 100.0 - ((boss1_percentage + boss2_percentage + enemies_percentage) / 3);

		} else {

			let alive = this.game.entities.enemies.length;
			let all   = this.enemies;

			if (alive > 0) {
				return 100.0 - (alive / all * 100);
			}

			return 0.0;

		}

	},

	Reset: function(width, height) {

		let center  = width / 2;
		let counted = 0;
		let offset  = 256;
		let wave_1  = -1 * 128; // cookie engineer and star destroyer

		this.boss1.Reset();
		this.boss1.SetPosition(64 + 128 + 16, 208);
		this.game.Spawn(this.boss1);
		counted++;

		this.boss2.Reset();
		this.boss2.SetPosition(width * 3/4, wave_1);
		this.boss2.SetSpeed(0, 30);
		this.game.Spawn(this.boss2);
		counted++;

		setTimeout(() => {
			this.boss1.SetInvincible(false);
		}, 12000);

		if (this.game.entities.enemies.length === counted) {
			console.info("Secret: Spawned all " + (counted).toString() + " enemies correctly.");
		} else {
			console.error("Secret: Spawned only " + (counted).toString() + " enemies!");
		}

	}

};
