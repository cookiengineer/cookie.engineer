
import { Cookie          } from "../entities/Cookie.mjs";
import { StarDestroyer   } from "../entities/StarDestroyer.mjs";
import { InterpolateLine } from "../math/InterpolateLine.mjs";

export const Level = function(game) {

	this.id   = "level3";
	this.game = game;

	// Accessed by the Game's Update Loop
	this.enemies = 17 + 32; // 32 orbiting shield cookies
	this.boss    = new StarDestroyer(this.game);

};

Level.prototype = {

	Progress: function() {

		if (this.boss.health >= 0 && this.boss.position.y >= 0) {

			let boss_percentage    = (this.boss.shield + this.boss.health) / 300 * 100;
			let enemies_percentage = (this.game.entities.enemies.length / this.enemies * 100);

			return 100.0 - ((boss_percentage + enemies_percentage) / 2);

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

		let counted = 0;
		let offset  = 256;
		let wave_1  = (-height / 2) - 1 * 128;
		let wave_2  = (-height / 2) - 1 * 128 - 3 * offset; // star destroyer

		InterpolateLine(width, -320, wave_1 - 128, -32, wave_1, 48, (x, y) => {

			let cookie = new Cookie();

			cookie.SetPosition(x, y);
			this.game.Spawn(cookie);
			counted++;

		});

		InterpolateLine(width, +32, wave_1, +320, wave_1 - 128, 48, (x, y) => {

			let cookie = new Cookie();

			cookie.SetPosition(x, y);
			this.game.Spawn(cookie);
			counted++;

		});

		this.boss.Reset();
		this.boss.SetPosition((+width / 2) - this.boss.radius - 64, wave_2);
		this.boss.SetSpeed(0, 30);
		this.game.Spawn(this.boss);
		counted++;

		if (this.game.entities.enemies.length === counted) {
			console.info("Level3: Spawned all " + (counted).toString() + " enemies correctly.");
		} else {
			console.error("Level3: Spawned only " + (counted).toString() + " enemies!");
		}

	}

};
