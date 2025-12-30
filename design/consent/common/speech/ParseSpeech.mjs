
import { phonemes as sorted_phonemes } from "./phonemes.mjs";

const parse_word_into_phonemes = (word, start_time, end_time) => {

	let phonemes = [];
	let timeline = [];

	while (word.length > 0) {

		let found = sorted_phonemes.find((str) => word.startsWith(str)) || null;
		if (found !== null) {
			phonemes.push(found);
			word = word.substr(found.length);
		}

	}

	let time_per_phoneme = (end_time - start_time) / phonemes.length;

	for (let t = 0; t < phonemes.length; t++) {
		timeline.push((start_time + time_per_phoneme * t) | 0);
	}

	return { phonemes, timeline };

};

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

				let { phonemes, timeline } = parse_word_into_phonemes(word, config["timeline"][s], config["timeline"][s + 1]);

				phonemes.forEach((phoneme) => {
					speech["phonemes"].push(phoneme);
				});

				timeline.forEach((time) => {
					speech["timeline"].push(time);
				});

			} else {

				let { phonemes, timeline } = parse_word_into_phonemes(word, config["timeline"][s], config["length"]);

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
