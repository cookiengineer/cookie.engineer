
import { Cookie           } from "../entities/Cookie.mjs";
import { Meteor           } from "../entities/Meteor.mjs";
import { InterpolateLine  } from "../math/InterpolateLine.mjs";
import { InterpolateGrid  } from "../math/InterpolateGrid.mjs";
import { InterpolateOrbit } from "../math/InterpolateOrbit.mjs";

export const Level = function(game) {

	this.id   = "level2";
	this.game = game;

	// Accessed by the Game's Update Loop
	this.enemies = 101;

};

Level.prototype = {

	Progress: function() {

		let alive = this.game.entities.enemies.length;
		let all   = this.enemies;

		if (alive > 0) {
			return 100.0 - (alive / all * 100);
		}

		return 0.0;

	},

	Reset: function(width, height) {

		let center  = width / 2;
		let counted = 0;
		let offset  = 256;
		let wave_1  = -1 * 128;
		let wave_2  = -1 * 128 - 1 * offset;
		let wave_3  = -1 * 128 - 2 * offset;
		let wave_4  = -1 * 128 - 4 * offset; // meteor
		let wave_5  = -1 * 128 - 6 * offset;
		let wave_6  = -1 * 128 - 8 * offset; // meteor

		InterpolateLine(width, center - 128, wave_1, center + 128, wave_1, 48, (x, y) => {

			let cookie = new Cookie();

			cookie.SetPosition(x, y);
			this.game.Spawn(cookie);
			counted++;

		});

		InterpolateGrid(width, center - 144, wave_2, center + 144, wave_2 - 256, 64, (x, y) => {

			let cookie = new Cookie();

			cookie.SetPosition(x, y);
			this.game.Spawn(cookie);
			counted++;

		});

		InterpolateLine(width, center - 144, wave_3, center + 256, wave_3 - 256, 64, (x, y) => {

			let cookie = new Cookie();

			cookie.SetPosition(x, y);
			this.game.Spawn(cookie);
			counted++;

		});

		((x, y) => {

			let meteor = new Meteor();

			meteor.SetPosition(x, y);
			this.game.Spawn(meteor);
			counted++;

			InterpolateOrbit(x, y, meteor.radius + 32, 16, (cx, cy, radius, angle) => {

				let cookie = new Cookie();

				cookie.OrbitAround(meteor, radius, 30, angle);
				cookie.SetPosition(cx, cy);
				this.game.Spawn(cookie);
				counted++;

			});

		})(center - 128, wave_4);


		InterpolateLine(width, center + 256, wave_5, center - 256, wave_5 - 256, 64, (x, y) => {

			let cookie = new Cookie();

			cookie.SetPosition(x, y);
			this.game.Spawn(cookie);
			counted++;

		});

		((x, y) => {

			let meteor = new Meteor();

			meteor.SetPosition(x, y);
			this.game.Spawn(meteor);
			counted++;

			InterpolateOrbit(x, y, meteor.radius + 32, 32, (cx, cy, radius, angle) => {

				let cookie = new Cookie();

				cookie.OrbitAround(meteor, radius, 30, angle);
				cookie.SetPosition(cx, cy);
				this.game.Spawn(cookie);
				counted++;

			});

		})(center + 128, wave_6);

		if (this.game.entities.enemies.length === counted) {
			console.info("Level2: Spawned all " + (counted).toString() + " enemies correctly.");
		} else {
			console.error("Level2: Spawned only " + (counted).toString() + " enemies!");
		}

	}

};
