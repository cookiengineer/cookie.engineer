
import { Simulation } from './source/Simulation.mjs';



const SIMULATION = window.SIMULATION = new Simulation();
const control    = function(/* e */) {

	let player = SIMULATION.game.planes[0] || null;
	if (player !== null) {
		player.jump();
	}

};


let fps_buttons = Array.from(document.querySelectorAll('button.set-fps'));
if (fps_buttons.length > 0) {

	fps_buttons.forEach((button) => {

		button.onclick = () => {

			let fps = parseInt(button.getAttribute('data-fps'), 10);

			if (Number.isNaN(fps) === false && fps > 0) {
				SIMULATION.setFPS(fps);
			}

		};

	});

}


let manual_button = document.querySelector('button#game-manual');
if (manual_button !== null) {

	manual_button.onclick = () => {

		manual_button.setAttribute('disabled', true);
		fps_buttons.forEach((button) => button.setAttribute('disabled', true));

		SIMULATION.stop();

		setTimeout(() => {

			SIMULATION.game.population = [];
			SIMULATION.game.setFPS(60);
			SIMULATION.game.start();

			SIMULATION.update();
			SIMULATION.render();

			document.querySelector('canvas').addEventListener('click', control);
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

		SIMULATION.stop();

		setTimeout(() => {

			SIMULATION.setFPS(60);

			SIMULATION.start();
			SIMULATION.update();
			SIMULATION.render();

			document.querySelector('canvas').removeEventListener('click', control);
			manual_button.removeAttribute('disabled');

		}, 500);

	};

	auto_button.removeAttribute('disabled');

}

