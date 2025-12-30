
import { ParseSpeech    } from "./ParseSpeech.mjs";
import { audio_context  } from "./audio_context.mjs";
import { audio_buffers  } from "./audio_buffers.mjs";
import { config_buffers } from "./config_buffers.mjs";
import { speech_buffers } from "./speech_buffers.mjs";

const supports = {
	"mp3":  false,
	"m4a":  false,
	"opus": false
};

(() => {

	let check = new Audio();

	if (check.canPlayType("audio/mpeg")) {
		supports["mp3"] = true;
	}

	if (check.canPlayType("audio/mp4")) {
		supports["m4a"] = true;
	}

	if (check.canPlayType("audio/ogg; codecs=\"opus\"")) {
		supports["opus"] = true;
	}

	check = null;

})();

export const LoadSpeech = (name, config_url, audio_urls) => {

	let check_buffer = audio_buffers[name] || null;
	let check_speech = speech_buffers[name] || null;
	let check_config = config_buffers[name] || null;

	if (check_buffer !== null && check_speech !== null && check_config !== null) {

		return new Promise((resolve, reject) => {
			resolve(check_buffer, check_speech, check_config);
		});

	} else {

		return new Promise((resolve, reject) => {

			let supported_url = audio_urls.find((url) => {

				if (supports["opus"] === true) {

					if (url.pathname.split("/").pop().endsWith(".opus")) {
						return true;
					}

				}

				if (supports["m4a"] === true) {

					if (url.pathname.split("/").pop().endsWith(".m4a")) {
						return true;
					}

				}

				if (supports["mp3"] === true) {

					if (url.pathname.split("/").pop().endsWith(".mp3")) {
						return true;
					}

				}

				return false;

			}) || null;

			if (supported_url !== null) {

				fetch(supported_url).then((response) => {
					return response.arrayBuffer();
				}).then((buffer) => {
					return audio_context.decodeAudioData(buffer);
				}).then((buffer) => {

					fetch(config_url).then((response) => {
						return response.json();
					}).then((config) => {

						let speech = ParseSpeech(config);

						audio_buffers[name]  = buffer;
						config_buffers[name] = config;
						speech_buffers[name] = speech;

						resolve(buffer, speech, config);

					}).catch((err) => {
						reject(err);
					});

				}).catch((err) => {
					reject(err);
				});

			} else {
				reject(new Error("No supported audio file format provided"));
			}

		});

	}

};

