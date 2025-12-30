
export const Phonemes = {};

[ "a", "e", "i" ].forEach((phoneme) => {

	Phonemes[phoneme] = [{
		"start": { x:  44, y: 124 },
		"end":   { x: 214, y: 156 },
		"cp1":   { x:  15, y: 212 },
		"cp2":   { x: 140, y: 261 }
	}, {
		"start": { x: 214, y: 156 },
		"end":   { x:  44, y: 124 },
		"cp1":   { x: 214, y: 156 },
		"cp2":   { x:  44, y: 124 }
	}];

});

[ "o" ].forEach((phoneme) => {

	Phonemes[phoneme] = [{
		"start": { x:  68, y: 153 },
		"end":   { x: 168, y: 172 },
		"cp1":   { x:  85, y: 210 },
		"cp2":   { x: 120, y: 220 }
	}, {
		"start": { x: 168, y: 172 },
		"end":   { x:  68, y: 153 },
		"cp1":   { x: 150, y: 125 },
		"cp2":   { x:  95, y: 125 }
	}];

});

[ "ou", "u" ].forEach((phoneme) => {

	Phonemes[phoneme] = [{
		"start": { x:  72, y: 170 },
		"end":   { x: 164, y: 190 },
		"cp1":   { x: 114, y: 192 },
		"cp2":   { x: 114, y: 192 }
	}, {
		"start": { x: 164, y: 190 },
		"end":   { x:  72, y: 170 },
		"cp1":   { x: 140, y: 155 },
		"cp2":   { x: 105, y: 150 }
	}];

});

[ "c", "d", "n", "s", "x", "z" ].forEach((phoneme) => {

	Phonemes[phoneme] = [{
		"start": { x:  30, y: 135 },
		"end":   { x: 228, y: 165 },
		"cp1":   { x:  25, y: 195 },
		"cp2":   { x: 170, y: 235 }
	}, {
		"start": { x: 228, y: 165 },
		"end":   { x:  30, y: 135 },
		"cp1":   { x: 184, y: 170 },
		"cp2":   { x:  64, y: 144 }
	}];

});

[ "ck", "g", "k" ].forEach((phoneme) => {

	Phonemes[phoneme] = [{
		"start": { x:  46, y: 160 },
		"end":   { x: 188, y: 188 },
		"cp1":   { x:  70, y: 180 },
		"cp2":   { x: 140, y: 200 }
	}, {
		"start": { x: 188, y: 188 },
		"end":   { x:  46, y: 160 },
		"cp1":   { x: 146, y: 141 },
		"cp2":   { x: 108, y: 133 }
	}];

});

[ "l", "r" ].forEach((phoneme) => {

	Phonemes[phoneme] = [{
		"start": { x:  15, y: 120 },
		"end":   { x: 235, y: 160 },
		"cp1":   { x:  50, y: 232 },
		"cp2":   { x: 150, y: 250 }
	}, {
		"start": { x: 235, y: 160 },
		"end":   { x:  15, y: 120 },
		"cp1":   { x: 214, y: 156 },
		"cp2":   { x:  44, y: 124 }
	}];

});

[ "b", "m", "p" ].forEach((phoneme) => {

	Phonemes[phoneme] = [{
		"start": { x:  55, y: 170 },
		"end":   { x: 170, y: 195 },
		"cp1":   { x:  65, y: 180 },
		"cp2":   { x: 160, y: 200 }
	}, {
		"start": { x: 170, y: 195 },
		"end":   { x:  55, y: 170 },
		"cp1":   { x: 165, y: 190 },
		"cp2":   { x:  60, y: 165 }
	}];

});

[ "f", "v" ].forEach((phoneme) => {

	Phonemes[phoneme] = [{
		"start": { x:  45, y: 150 },
		"end":   { x: 195, y: 175 },
		"cp1":   { x:  80, y: 200 },
		"cp2":   { x: 140, y: 210 }
	}, {
		"start": { x: 195, y: 175 },
		"end":   { x:  45, y: 150 },
		"cp1":   { x: 195, y: 175 },
		"cp2":   { x:  45, y: 150 }
	}];

});

[ "ea", "ee" ].forEach((phoneme) => {

	Phonemes[phoneme] = [{
		"start": { x:  46, y: 160 },
		"end":   { x: 188, y: 188 },
		"cp1":   { x:  70, y: 180 },
		"cp2":   { x: 140, y: 200 }
	}, {
		"start": { x: 188, y: 188 },
		"end":   { x:  46, y: 160 },
		"cp1":   { x: 146, y: 141 },
		"cp2":   { x: 108, y: 133 }
	}];

});

[ "th", "t", "h" ].forEach((phoneme) => {

	Phonemes[phoneme] = [{
		"start": { x:  40, y: 155 },
		"end":   { x: 190, y: 185 },
		"cp1":   { x:  70, y: 180 },
		"cp2":   { x: 140, y: 200 }
	}, {
		"start": { x: 190, y: 185 },
		"end":   { x:  40, y: 155 },
		"cp1":   { x: 145, y: 135 },
		"cp2":   { x: 120, y: 125 }
	}];

});

[ "ch", "sh", "j" ].forEach((phoneme) => {

	Phonemes[phoneme] = [{
		"start": { x:  38, y: 135 },
		"end":   { x: 205, y: 168 },
		"cp1":   { x:  50, y: 200 },
		"cp2":   { x: 170, y: 220 }
	}, {
		"start": { x: 205, y: 168 },
		"end":   { x:  38, y: 135 },
		"cp1":   { x: 160, y: 145 },
		"cp2":   { x:  90, y: 130 }
	}];

});

[ "q", "y", "w" ].forEach((phoneme) => {

	Phonemes[phoneme] = [{
		"start": { x:  70, y: 160 },
		"end":   { x: 165, y: 178 },
		"cp1":   { x:  95, y: 202 },
		"cp2":   { x: 130, y: 210 }
	}, {
		"start": { x: 165, y: 178 },
		"end":   { x:  70, y: 160 },
		"cp1":   { x: 150, y: 140 },
		"cp2":   { x:  95, y: 130 }
	}];

});

