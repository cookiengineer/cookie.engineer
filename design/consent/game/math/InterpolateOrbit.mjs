
export const InterpolateOrbit = (x, y, radius, steps, callback) => {

	callback = typeof callback === "function" ? callback : null;

	if (callback !== null) {

		for (let s = 0; s < steps; s++) {

			let angle = ((s / steps) * 360) | 0;
			let rad   = angle * (Math.PI / 180);
			let pos_x = x + Math.cos(rad) * radius;
			let pos_y = y + Math.sin(rad) * radius;

			callback(pos_x, pos_y, radius, angle);

		}

	}

};
