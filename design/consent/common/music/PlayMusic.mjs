
import { audio_context } from "./audio_context.mjs";
import { music_buffers } from "./music_buffers.mjs";
import { playing       } from "./playing.mjs";

export const PlayMusic = (name, callback) => {

	callback = typeof callback === "function" ? callback : null;

	if (playing.buffersource !== null) {

		try {
			playing.buffersource.stop();
		} catch(_err) {
			// Do Nothing
		}

		playing.buffersource.disconnect();
		playing.buffersource = null;

	}

	let buffer = music_buffers[name] || null;
	if (buffer !== null) {

		let source = audio_context.createBufferSource();

		source.buffer = buffer;
		source.connect(audio_context.destination);

		if (callback !== null) {

			source.loop = false;
			source.onended = () => {

				if (audio_context.currentTime < buffer.duration) {

					// Playback was stopped, fire no callback
					playing.buffersource = null;

				} else {

					playing.buffersource = null;
					callback();

				}

			};

		} else {
			source.loop = true;
		}

		source.start();

		playing.buffersource = source;

	}

};


