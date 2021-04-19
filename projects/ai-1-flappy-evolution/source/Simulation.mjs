
import { Game      } from './Game.mjs';
import { Evolution } from './Evolution.mjs';



const Simulation = function() {

	this.evolution = new Evolution({ population: 64 });
	this.fps       = 60;
	this.game      = new Game();

};


Simulation.prototype = {

	start: function() {

		let population = this.evolution.cycle();

		this.game.population = population;
		this.game.start();

	},

	restart: function() {

		let population = this.evolution.cycle();

		this.game.population = population;
		this.game.restart();

		this.update();
		this.render();

	},

	stop: function() {

		this.game.stop();

	},

	update: function() {

		if (this.game._has_ended === false) {
			this.game.update();
		}

		if (this.game._has_ended === false) {
			setTimeout(() => this.update(), 1000 / this.fps);
		} else {
			setTimeout(() => this.restart(), 16);
		}

	},

	render: function() {

		if (this.game._has_ended === false) {
			this.game.render();
		}

		if (this.game._has_ended === false) {
			requestAnimationFrame(() => this.render());
		}

	},



	/*
	 * CUSTOM API
	 */

	setFPS: function(fps) {

		fps = typeof fps === 'number' ? fps : 60;


		if (this.fps !== fps) {

			this.fps = fps;
			this.game.setFPS(fps);

			return true;

		}


		return false;

	}

};



export { Simulation };

