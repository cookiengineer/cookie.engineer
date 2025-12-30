
const unsorted_phonemes = [
	"a", "e", "i",
	"o",
	"u",
	"c", "d", "n", "s", "x", "y", "z",
	"g", "k",
	"l", "r",
	"b", "m", "p",
	"f", "v",
	"ea", "ee",
	"th", "t", "h",
	"ch", "sh", "j",
	"q", "y", "w"
];

export const phonemes = unsorted_phonemes.sort((a, b) => {

	if (a.length > b.length) {
		return -1;
	} else if (b.length > a.length) {
		return 1;
	} else {
		return a.localeCompare(b);
	}

});

