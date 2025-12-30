
export const InterpolateColor = (color1, color2, f) => {

	if (f >= 1.0) {
		f = 1.0;
	}

	return [
		(color1[0] + f * (color2[0] - color1[0]) | 0),
		(color1[1] + f * (color2[1] - color1[1]) | 0),
		(color1[2] + f * (color2[2] - color1[2]) | 0)
	];

};

