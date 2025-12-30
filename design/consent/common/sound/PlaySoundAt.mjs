
import { audio_context } from "./audio_context.mjs";
import { sound_buffers } from "./sound_buffers.mjs";

export const PlaySoundAt = (name, position, callback) => {

	position = typeof position === "number"   ? position : 0.0;
	callback = typeof callback === "function" ? callback : null;

	if (position > 1.0) {
		position = 1.0;
	}

	if (position < -1.0) {
		position = -1.0;
	}

	let buffer = sound_buffers[name] || null;
	if (buffer !== null) {

		let source = audio_context.createBufferSource();
		let panner = audio_context.createStereoPanner();

		source.buffer = buffer;
		panner.pan.value = position;

		source.connect(panner).connect(audio_context.destination);

		if (callback !== null) {
			source.onended = () => {
				callback();
			};
		}

		source.start();

	}

};
