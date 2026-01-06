
import { ParseWordIntoPhonemes } from "./ParseWordIntoPhonemes.mjs";

export const ParseSpeech = (config) => {

	let speech = {
		"phonemes": [],
		"timeline": [],
		"length":   0
	};

	if (typeof config["length"] === "number" && config["sentence"].length > 0) {

		speech["length"] = config["length"];

		config["sentence"].forEach((word, s) => {

			if (word === "." || word === "?" || word === "!") {

				// Special case
				speech["phonemes"].push("");
				speech["timeline"].push(config["timeline"][s]);

			} else if (s < config["sentence"].length - 1) {

				let { phonemes, timeline } = ParseWordIntoPhonemes(word, config["timeline"][s], config["timeline"][s + 1]);

				phonemes.forEach((phoneme) => {
					speech["phonemes"].push(phoneme);
				});

				timeline.forEach((time) => {
					speech["timeline"].push(time);
				});

			} else {

				let { phonemes, timeline } = ParseWordIntoPhonemes(word, config["timeline"][s], config["length"]);

				phonemes.forEach((phoneme) => {
					speech["phonemes"].push(phoneme);
				});

				timeline.forEach((time) => {
					speech["timeline"].push(time);
				});

			}

		});

	}

	return speech;

};
