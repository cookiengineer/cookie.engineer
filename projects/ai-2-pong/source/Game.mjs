
import { Agent   } from './Agent.mjs';
import { Ball    } from './Ball.mjs';
import { Paddle  } from './Paddle.mjs';
import { Twister } from './Twister.mjs';



let CANVAS  = document.querySelector('canvas');
let CONTEXT = null;


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



const get_closest_ball = function(paddle) {

	let balls = this;
	let px    = paddle.x;
	let py    = paddle.y;
	let found = null;
	let fdist = Infinity;


	balls.forEach(function(ball) {

		let dx   = ball.x - px;
		let dy   = ball.y - py;
		let dist = Math.sqrt(Math.pow(dx, 2) + Math.pow(dy, 2));

		if (dist < fdist) {
			found = ball;
			fdist = dist;
		}

	});


	return found;

};



const Game = function() {

	this.balls   = [];
	this.paddles = [];
	this.fps     = 60;

	this.width      = CANVAS.width;
	this.height     = CANVAS.height;
	this.population = [];
	this.training   = [];

	this._has_ended  = false;
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

			this.balls = [
				new Ball()
			];

			this.paddles = this.population.map(() => {
				return new Paddle({ type: 'auto' });
			});

		} else {

			// Manual Mode

			this.balls = [
				new Ball()
			];

			this.paddles = [
				new Paddle({ type: 'manual' }),
				new Paddle({ type: 'auto'   })
			];

			this.population = [
				null,
				new Agent()
			];

		}


		// Sweet statistics and stuff
		this._info.alive = this.paddles.length;
		this._info.score = 0;

		// Seed-based Randomizer is IMPORTANT
		// - used only for Ball Velocity generation
		// - this allows identical level structure
		// - still random, but in same order
		// - Math.random() will lead to worse performance
		// - Math.random() will let NNs not learn so efficiently

		this._randomizer = new Twister(1337);

		this.restart();

	},

	restart: function(learn) {

		this._has_ended = false;


		if (learn === true) {

			this.paddles.forEach((paddle, p) => {

				let agent        = this.population[p] || null;
				let closest_ball = get_closest_ball.call(this.balls, paddle);

				if (agent !== null && closest_ball !== null) {

					let inputs = [
						paddle.x        / this.width,
						paddle.y        / this.height,
						closest_ball.x  / this.width,
						closest_ball.y  / this.height,
						closest_ball.vx / 25,
						closest_ball.vy / 25
					];

					let outputs = [
						closest_ball.y / this.height
					];

					agent.learn(inputs, outputs);


					this.training.push({
						inputs:  inputs,
						outputs: outputs
					});

				}

			});


			this.training.forEach((knowledge) => {

				this.population.forEach((agent) => {

					if (agent !== null) {
						agent.learn(knowledge.inputs, knowledge.outputs);
					}

				});

			});

		}


		this.balls.forEach((ball) => {

			ball.x     = this.width  / 2;
			ball.y     = this.height / 2;
			ball.alive = true;
			ball.trail = [];

		});

		this.paddles.forEach((paddle, p) => {

			if (p % 2 === 0) {
				paddle.x = 60;
			} else {
				paddle.x = this.width - 60;
			}

			paddle.y = this.height / 2;

		});


		this._info.generation++;
		this._info.highscore = Math.max(this._info.score, this._info.highscore);
		this._info.score     = 0;


		this.balls.forEach((ball) => {

			let rx = this._randomizer.random();
			let ry = this._randomizer.random();

			ball.vx = rx > 0.5 ? 8 : -8;
			ball.vy = (ry * 2 - 1) * 8;

		});

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

			context.fillStyle = '#404552';
			context.fillRect(0, 0, this.width, this.height);


			for (let b = 0, bl = this.balls.length; b < bl; b++) {

				let ball = this.balls[b];
				if (ball.alive === true) {
					ball.render(context);
				}

			}

			for (let p = 0, pl = this.paddles.length; p < pl; p++) {
				this.paddles[p].render(context);
			}


			context.fillStyle = '#ffffff';
			context.font      = '20px "DejaVu Sans Mono", sans-serif';

			context.fillText('Score:      ' + this._info.score,      10, 25);
			context.fillText('High Score: ' + this._info.highscore,  10, 50);
			context.fillText('Generation: ' + this._info.generation, 10, 75);
			context.fillText('Agents:     ' + this._info.alive,      10, 100);

		}


		if (this._has_ended === false) {
			requestAnimationFrame(() => this.render());
		}

	},

	update: function() {

		if (this._has_ended === true) {
			return;
		}


		let balls      = this.balls;
		let paddles    = this.paddles;
		let population = this.population;
		let training   = this.training;


		let alive_balls = 0;

		for (let b = 0, bl = balls.length; b < bl; b++) {

			let ball = balls[b];

			if (ball.alive === true) {
				ball.update(this);
			}

			if (ball.alive === true) {
				alive_balls++;
			}

		}

		for (let p = 0, pl = paddles.length; p < pl; p++) {

			let agent        = population[p] || null;
			let paddle       = paddles[p];
			let closest_ball = get_closest_ball.call(balls, paddle);

			if (agent !== null && closest_ball !== null) {

				// Brain Computation
				// - First Sensor is relative Paddle Position
				// - Second Sensor is relative Ball Position
				// - Output is "To Move Up or Down or Do Nothing"

				let inputs  = [
					paddle.x / this.width,
					paddle.y / this.height,
					closest_ball.x / this.width,
					closest_ball.y / this.height,
					closest_ball.vx / 25,
					closest_ball.vy / 25
				];
				let result  = agent.compute(inputs);

				let rel_pos = paddle.y / this.height;
				if ((rel_pos - result) > 0.1) {
					paddle.move('up');
				} else if ((rel_pos - result) < 0.1) {
					paddle.move('down');
				} else {
					paddle.move('left');
				}


				// IMPORTANT:
				// - update Paddle position _AFTERWARDS_
				// - if FPS > 60, this allows hard
				//   computation cycles for slow machines

				let hit_something = paddle.update(this);
				if (hit_something === true) {

					this._info.score++;


					let outputs = [ closest_ball.y / this.height ];

					agent.learn(inputs, outputs);


					training.push({
						inputs:  inputs,
						outputs: outputs
					});

				}

			} else {

				// IMPORTANT:
				// - update Paddle position _AFTERWARDS_
				// - if FPS > 60, this allows hard
				//   computation cycles for slow machines

				paddle.update(this);

			}

		}


		if (alive_balls === 0) {
			this.restart(true);
		}


		if (this._has_ended === false) {

			setTimeout(() => {
				this.update();
			}, 1000 / this.fps);

		}

	}

};


export { Game };

