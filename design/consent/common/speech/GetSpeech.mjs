
import { audio_buffers  } from "./audio_buffers.mjs";
import { config_buffers } from "./config_buffers.mjs";
import { speech_buffers } from "./speech_buffers.mjs";

export const GetSpeech = (name) => {

	let buffer = audio_buffers[name] || null;
	let speech = speech_buffers[name] || null;
	let config = config_buffers[name] || null;

	if (buffer !== null && speech !== null && config !== null) {
		return [ buffer, speech, config ];
	} else if (buffer !== null && speech !== null) {
		return [ buffer, speech, null ];
	} else if (buffer !== null) {
		return [ buffer, null, null ];
	} else {
		return [ null, null, null ];
	}

};
