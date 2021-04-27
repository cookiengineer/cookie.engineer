
import { Agent } from './source/Agent.mjs';
import { Game  } from './source/Game.mjs';



const GAME    = window.GAME = new Game();
const control = function(e) {

	let direction = null;


	// Arrow Keys
	if (e.keyCode === 38) direction = 'up';
	if (e.keyCode === 40) direction = 'down';
	if (e.keyCode === 37) direction = 'left';
	if (e.keyCode === 39) direction = 'right';

	// WASD
	if (e.keyCode === 87) direction = 'up';
	if (e.keyCode === 83) direction = 'down';
	if (e.keyCode === 65) direction = 'left';
	if (e.keyCode === 68) direction = 'right';


	if (direction !== null) {

		let player = GAME.paddles[0] || null;
		if (player !== null) {
			player.move(direction);
		}

		e.preventDefault();
		e.stopPropagation();

	}

};


let fps_buttons = Array.from(document.querySelectorAll('button.set-fps'));
if (fps_buttons.length > 0) {

	fps_buttons.forEach((button) => {

		button.onclick = () => {

			let fps = parseInt(button.getAttribute('data-fps'), 10);

			if (Number.isNaN(fps) === false && fps > 0) {
				GAME.setFPS(fps);
			}

		};

	});

}


let manual_button = document.querySelector('button#game-manual');
if (manual_button !== null) {

	manual_button.onclick = () => {

		manual_button.setAttribute('disabled', true);
		fps_buttons.forEach((button) => button.setAttribute('disabled', true));

		GAME.stop();

		setTimeout(() => {

			GAME.population = [ null, new Agent() ];
			GAME.setFPS(60);

			GAME.start();
			GAME.update();
			GAME.render();

			document.addEventListener('keydown', control, true);
			auto_button.removeAttribute('disabled');

		}, 500);

	};

	manual_button.removeAttribute('disabled');

}


let auto_button = document.querySelector('button#game-auto');
if (auto_button !== null) {

	auto_button.onclick = () => {

		auto_button.setAttribute('disabled', true);
		fps_buttons.forEach((button) => button.removeAttribute('disabled'));

		GAME.stop();

		setTimeout(() => {

			GAME.population = [ new Agent(), new Agent() ];
			GAME.setFPS(60);

			GAME.start();
			GAME.update();
			GAME.render();

			document.removeEventListener('keydown', control);
			manual_button.removeAttribute('disabled');

		}, 500);

	};

	auto_button.removeAttribute('disabled');

}
