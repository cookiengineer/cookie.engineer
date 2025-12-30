
import { Goal      } from './Goal.mjs';
import { Plane     } from './Plane.mjs';
import { Twister   } from './Twister.mjs';



let CANVAS  = document.querySelector('canvas');
let CONTEXT = null;
let IMAGE   = null;


(function() {

	let img = new Image();

	img.onload = function() {
		IMAGE = this;
	};

	img.src = './source/Game.png';

})();


(function(document) {

	if (CANVAS === null) {

		CANVAS = document.createElement('canvas');
		CANVAS.width  = 800;
		CANVAS.height = 512;

		if (CANVAS.parentNode === null) {

			document.addEventListener('DOMContentLoaded', function() {
				document.body.appendChild(CANVAS);
			}, true);

		}

	}

	CONTEXT = CANVAS.getContext('2d');

})(window.document);



const Game = function() {

	this.planes = [];
	this.goals  = [];
	this.fps    = 60;

	this.width      = CANVAS.width;
	this.height     = CANVAS.height;
	this.population = [];

	this._has_ended  = false;
	this._background = 0;
	this._iterations = 0;
	this._info       = {
		alive:      0,
		generation: 0,
		highscore:  0,
		score:      0
	};
	this._randomizer = new Twister(1337);

};


Game.prototype = {

	setFPS: function(val) {

		val = typeof val === 'number' ? (val | 0) : 60;

		if (val > 0) {
			this.fps = val;
		}

	},

	start: function() {

		let population = this.population;
		if (population.length > 0) {

			// Autobattle Mode

			this.planes = this.population.map(() => {
				return new Plane();
			});

		} else {

			// Manual Mode

			this.planes = [
				new Plane()
			];

			this.population = [
				null
			];

		}


		// Sweet statistics and stuff
		this._info.alive = this.planes.length;
		this._info.score = 0;

		// Seed-based Randomizer is IMPORTANT
		// - used only for Hurdle (Goal) generation
		// - this allows identical level structure
		// - still random, but in same order
		// - Math.random() will lead to worse performance
		// - Math.random() will let NNs not learn so efficiently

		this._randomizer = new Twister(1337);

		this.restart();

	},

	restart: function(/* learn */) {

		this._has_ended  = false;
		this._iterations = 0;


		this.goals = [];

		this.planes.forEach((plane) => {

			plane.x       = 80;
			plane.y       = 250;
			plane.gravity = 0;
			plane.alive   = true;

		});

		this._info.generation++;
		this._info.highscore = Math.max(this._info.score, this._info.highscore);
		this._info.score     = 0;

		this._randomizer = new Twister(1337);

	},

	pause: function() {
		this._has_ended = true;
	},

	resume: function() {

		if (this._has_ended === true) {

			this._has_ended = false;

			this.update();
			this.render();

		}

	},

	stop: function() {
		this._has_ended = true;
	},

	render: function() {

		if (this._has_ended === true) {
			return;
		}


		let context = CONTEXT;
		if (context !== null) {

			context.clearRect(0, 0, this.width, this.height);

			if (IMAGE !== null) {

				let bg_width = IMAGE.width;

				for (let b = 0; b < Math.ceil(this.width / bg_width) + 1; b++) {

					context.drawImage(
						IMAGE,
						b * bg_width + Math.floor(this._background % bg_width),
						0
					);

				}

			}

			for (let g = 0, gl = this.goals.length; g < gl; g++) {

				let goal = this.goals[g];
				if (goal.alive === true) {
					goal.render(context);
				}

			}

			for (let p = 0, pl = this.planes.length; p < pl; p++) {

				let plane = this.planes[p];
				if (plane.alive === true) {
					plane.render(context);
				}

			}

			context.fillStyle = '#ffffff';
			context.font      = '20px "DejaVu Sans Mono", sans-serif';

			context.fillText('Score:      ' + this._info.score,      10, 25);
			context.fillText('High Score: ' + this._info.highscore,  10, 50);
			context.fillText('Generation: ' + this._info.generation, 10, 75);
			context.fillText('Agents:     ' + this._info.alive,      10, 100);

		}

	},

	update: function() {

		if (this._has_ended === true) {
			return;
		}


		let planes     = this.planes;
		let goals      = this.goals;
		let population = this.population;


		let alive_planes = 0;
		let next_goal    = 0;

		if (planes.length > 0 && goals.length > 0) {

			// Find Next Goal
			// - only if planes are available
			// - only if goals are available

			let agent = planes[0];
			let awh   = planes[0].width / 2;
			let gwh   = goals[0].width  / 2;

			for (let g = 0, gl = goals.length; g < gl; g++) {

				let goal = goals[g];

				// This is AABB collision
				// - if goal is "being passed through"
				// - else if next goal is ahead in X-position

				if (agent.x > goal.x && agent.x - awh < goal.x + gwh) {
					next_goal = goal.y / this.height;
					break;
				} else if (agent.x < goal.x - gwh) {
					next_goal = goal.y / this.height;
					break;
				}

			}

		} else {

			// No Goal available
			// - flap to the middle, so Planes won't die
			next_goal = 0.5;

		}


		for (let p = 0, pl = planes.length; p < pl; p++) {

			let agent = population[p] || null;
			let plane = planes[p];

			if (plane.alive === true) {

				if (agent !== null) {

					// Brain Computation
					// - First Sensor is relative Plane Position
					// - Second Sensor is relative Goal Position
					// - Output is "To Flap or Not to Flap"

					let inputs = [ plane.y / this.height, next_goal ];
					let result = agent.compute(inputs);
					if (result > 0.5) {
						plane.jump();
					}

				}


				// IMPORTANT:
				// - update Plane position _AFTERWARDS_
				// - If FPS > 60, this allows hard
				//   computation cycles for slow machines

				plane.update(this);


				// If Plane died in update() method,
				// track the Agent fitness. Less computation
				// intensive than tracking it always.

				if (plane.alive === true) {

					alive_planes++;

				} else {

					if (agent !== null) {
						agent.fitness = this._info.score;
					}

				}

			}

		}


		// Goals are updated _AFTERWARDS_
		// This is important, as Brain
		// Computation is dependent on
		// Goal Position.

		for (let g = 0, gl = goals.length; g < gl; g++) {

			let goal = goals[g];

			goal.update(this);

			if (goal.alive === false) {
				goals.splice(g, 1);
				gl--;
				g--;
			}

		}


		// Every Reset Iteration, generate
		// Goals. Seed-Based Randomizer (with
		// static seed) leads to identical
		// level structure after Game.start()
		// or "restart" was called again.

		if (this._iterations === 0) {

			let border = 128;

			goals.push(new Goal({
				x: this.width,
				y: border + Math.round(this._randomizer.random() * (this.height - border * 2))
			}));

		}


		// Background Shinyness and
		// Iterations for Goal Spawn

		this._background -= 0.5;
		this._iterations++;

		if (this._iterations === 90) {
			this._iterations = 0;
		}


		// Track the current Score
		// Track the High Score

		this._info.score++;
		this._info.highscore = Math.max(this._info.score, this._info.highscore);
		this._info.alive     = alive_planes;


		if (alive_planes === 0) {
			this._has_ended = true;
		}

	}

};



export { Game };

