
import { audio_buffers  } from "./audio_buffers.mjs";
import { config_buffers } from "./config_buffers.mjs";
import { speech_buffers } from "./speech_buffers.mjs";

export const InjectSpeech = (name, buffer, speech, config) => {

	name   = typeof name === "string"      ? name   : null;
	buffer = buffer instanceof AudioBuffer ? buffer : null;
	speech = speech instanceof Object      ? speech : null;
	config = config instanceof Object      ? config : null;

	if (name !== null && buffer !== null && speech !== null && config !== null) {

		audio_buffers[name] = buffer;
		speech_buffers[name] = speech;
		config_buffers[name] = config;

		return true;

	}

	return false;

};
