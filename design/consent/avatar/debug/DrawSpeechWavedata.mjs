
import { offscreen_buffers } from "./offscreen_buffers.mjs";

export const DrawSpeechWavedata = (ctx, identifier, scale, speech, wavedata) => {

	let offscreen_buffer = offscreen_buffers[identifier + "|wavedata"] || null;
	if (offscreen_buffer !== null) {

		ctx.drawImage(offscreen_buffer, 0, 0);

	} else {

		let offscreen_canvas  = document.createElement("canvas");
		let offscreen_context = offscreen_canvas.getContext("2d");

		offscreen_canvas.width  = speech["length"] * scale;
		offscreen_canvas.height = 128;

		let step      = Math.floor(wavedata.length / (speech["length"] * scale));
		let amplitude = 96 / 2;

		offscreen_context.clearRect(0, 0, offscreen_canvas.width, offscreen_canvas.height);
		offscreen_context.strokeStyle = "#0f99cb";
		offscreen_context.beginPath();

		for (let x = 0; x < offscreen_canvas.width; x++) {

			let min = 1.0;
			let max = -1.0;

			for (let y = 0; y < step; y++) {

				let value = wavedata[(x * step) + y];
				if (value < min) {
					min = value;
				}

				if (value > max) {
					max = value;
				}

				offscreen_context.moveTo(x, (1 + min) * amplitude);
				offscreen_context.lineTo(x, (1 + max) * amplitude);

			}

		}

		offscreen_context.stroke();
		offscreen_context.closePath();

		offscreen_buffers[identifier + "|wavedata"] = offscreen_canvas;

		ctx.drawImage(offscreen_canvas, 0, 0);

	}

};
