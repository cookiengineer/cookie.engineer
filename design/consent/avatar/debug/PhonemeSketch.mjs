
export const PhonemeSketch = {};

[ "AE", "AE0", "AE1", "AE2", "EH", "EH0", "EH1", "EH2" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 128, y: 128, w: 188, h: 104 };
});

[ "AO", "AO0", "AO1", "AO2", "OW", "OW0", "OW1", "OW2" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 384, y: 128, w: 104, h: 100 };
});

[ "UH", "UH0", "UH1", "UH2", "UW", "UW0", "UW1", "UW2", "AW", "AW0", "AW1", "AW2" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 640, y: 128, w: 102, h: 104 };
});

[ "D", "N", "S", "Z" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 896, y: 128, w: 244, h:  92 };
});

[ "G", "K" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 128, y: 384, w: 150, h:  76 };
});

[ "L", "R", "ER", "ER0", "ER1", "ER2" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 384, y: 384, w: 234, h: 112 };
});

[ "B", "M", "P" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 640, y: 384, w: 172, h:  84 };
});

[ "F", "V" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 896, y: 384, w: 178, h:  78 };
});

[ "IH", "IH0", "IH1", "IH2", "IY", "IY0", "IY1", "IY2" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 128, y: 640, w: 166, h:  82 };
});

[ "T", "TH", "DH", "HH" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 384, y: 640, w: 168, h:  82 };
});

[ "CH", "SH", "JH", "ZH" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 640, y: 640, w: 172, h:  78 };
});

[ "W", "Y" ].forEach((phoneme) => {
	PhonemeSketch[phoneme] = { x: 896, y: 640, w: 100, h:  82 };
});

