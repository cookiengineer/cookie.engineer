
import { Simulation } from './source/Simulation.mjs';



const SIMULATION = window.SIMULATION = new Simulation({
	active:  0,
	games:  16
});

SIMULATION.setFPS(300);
SIMULATION.start();
SIMULATION.update();
SIMULATION.render();



let next_button = document.querySelector('aside button');
if (next_button !== null) {

	next_button.onclick = () => {
		SIMULATION.evolution.cycle();
	};

	next_button.removeAttribute('disabled');

}


let menu = document.querySelector('aside menu');
if (menu !== null) {

	menu.innerHTML = SIMULATION.games.map((game, g) => {
		return '<li><button title="View Game #' + g + '" onclick="window.SIMULATION.setActive(' + g + ')">#' + g + '</button></li>';
	}).join('');

}

