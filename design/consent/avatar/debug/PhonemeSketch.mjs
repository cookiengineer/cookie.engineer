
export const PhonemeSketch = {};

[ "a", "e", "i" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 128, y: 128, w: 188, h: 104 };
});

[ "o" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 384, y: 128, w: 104, h: 100 };
});

[ "ou", "u" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 640, y: 128, w: 102, h: 104 };
});

[ "c", "d", "n", "s", "x", "z" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 896, y: 128, w: 244, h:  92 };
});

[ "ck", "g", "k" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 128, y: 384, w: 150, h:  76 };
});

[ "l", "r" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 384, y: 384, w: 234, h: 112 };
});

[ "b", "m", "p" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 640, y: 384, w: 172, h:  84 };
});

[ "f", "v" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 896, y: 384, w: 178, h:  78 };
});

[ "ea", "ee" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 128, y: 640, w: 166, h:  82 };
});

[ "th", "t", "h" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 384, y: 640, w: 168, h:  82 };
});

[ "ch", "sh", "j" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 640, y: 640, w: 172, h:  78 };
});

[ "q", "y", "w" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 896, y: 640, w: 100, h:  82 };
});

