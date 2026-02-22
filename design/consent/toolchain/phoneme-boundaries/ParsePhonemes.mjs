
import { phonemes as sorted_phonemes } from "./phonemes.mjs";

export const ParsePhonemes = (word) => {

	let phonemes = [];

	while (word.length > 0) {

		let found = sorted_phonemes.find((str) => word.startsWith(str)) || null;
		if (found !== null) {
			phonemes.push(found);
			word = word.substr(found.length);
		}

	}

	return phonemes;

};
