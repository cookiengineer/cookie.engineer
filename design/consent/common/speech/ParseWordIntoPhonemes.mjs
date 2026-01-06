
import { dictionary } from "./dictionary.mjs";

export const ParseWordIntoPhonemes = (word, start_time, end_time) => {

	let phonemes = [];
	let timeline = [];

	let tmp = dictionary[word] || null;
	if (tmp !== null) {

		tmp.forEach((phoneme) => {
			phonemes.push(phoneme);
		});

	} else {
		console.error("Cannot find \"" + word + "\" in dictionary!");
	}

	let time_per_phoneme = (end_time - start_time) / phonemes.length;

	for (let t = 0; t < phonemes.length; t++) {
		timeline.push((start_time + time_per_phoneme * t) | 0);
	}

	return { phonemes, timeline };

};
