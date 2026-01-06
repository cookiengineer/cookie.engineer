
export const Phonemes = {};

[
	"AE", "AE0", "AE1", "AE2",
	"EH", "EH0", "EH1", "EH2",
].forEach((phoneme) => {

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

[
	"AO", "AO0", "AO1", "AO2",
	"OW", "OW0", "OW1", "OW2"
].forEach((phoneme) => {

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

[
	"UH", "UH0", "UH1", "UH2",
	"UW", "UW0", "UW1", "UW2",
	"AW", "AW0", "AW1", "AW2"
].forEach((phoneme) => {

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

[
	"D", "N", "S", "Z"
].forEach((phoneme) => {

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

[
	"G", "K"
].forEach((phoneme) => {

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

[
	"L", "R",
	"ER", "ER0", "ER1", "ER2"
].forEach((phoneme) => {

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

[
	"B", "M", "P"
].forEach((phoneme) => {

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

[
	"F", "V"
].forEach((phoneme) => {

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

[
	"IH", "IH0", "IH1", "IH2",
	"IY", "IY0", "IY1", "IY2"
].forEach((phoneme) => {

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

[
	"T", "TH", "DH", "HH"
].forEach((phoneme) => {

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

[
	"CH", "SH", "JH", "ZH"
].forEach((phoneme) => {

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

[
	"W", "Y"
].forEach((phoneme) => {

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

