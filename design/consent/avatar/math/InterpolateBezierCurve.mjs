
export const InterpolateBezierCurve = (curve1, curve2, f) => {

	if (f >= 1.0) {
		f = 1.0;
	}

	return {
		start: {
			x: curve1.start.x + f * (curve2.start.x - curve1.start.x),
			y: curve1.start.y + f * (curve2.start.y - curve1.start.y)
		},
		end: {
			x: curve1.end.x + f * (curve2.end.x - curve1.end.x),
			y: curve1.end.y + f * (curve2.end.y - curve1.end.y)
		},
		cp1: {
			x: curve1.cp1.x + f * (curve2.cp1.x - curve1.cp1.x),
			y: curve1.cp1.y + f * (curve2.cp1.y - curve1.cp1.y)
		},
		cp2: {
			x: curve1.cp2.x + f * (curve2.cp2.x - curve1.cp2.x),
			y: curve1.cp2.y + f * (curve2.cp2.y - curve1.cp2.y)
		}
	};

};

