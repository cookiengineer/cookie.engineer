
import { audio_context } from "./audio_context.mjs";
import { music_buffers } from "./music_buffers.mjs";

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

export const LoadMusic = (name, audio_urls) => {

	let check = music_buffers[name] || null;
	if (check !== null) {

		return new Promise((resolve, reject) => {
			resolve(music_buffers[name]);
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

					music_buffers[name] = buffer;
					resolve(buffer);

				}).catch((err) => {
					reject(err);
				});

			} else {
				reject(new Error("No supported audio file format provided"));
			}

		});

	}

};
