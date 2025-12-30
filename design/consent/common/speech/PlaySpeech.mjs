
import { audio_context } from "./audio_context.mjs";
import { audio_buffers } from "./audio_buffers.mjs";

export const PlaySpeech = (name, callback) => {

	callback = typeof callback === "function" ? callback : null;

	let buffer = audio_buffers[name] || null;
	if (buffer !== null) {

		let source = audio_context.createBufferSource();

		source.buffer = buffer;
		source.connect(audio_context.destination);

		if (callback !== null) {
			source.onended = () => {
				callback();
			};
		}

		source.start();

	}

};
