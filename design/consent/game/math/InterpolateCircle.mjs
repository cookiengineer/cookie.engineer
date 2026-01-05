
export const InterpolateCircle = (x, y, radius, angle_from, angle_to, steps, callback) => {

	callback = typeof callback === "function" ? callback : null;

	if (callback !== null) {

		for (let s = 0; s < steps; s++) {

			let angle = (angle_from + ((s / steps) * (angle_to - angle_from))) | 0;
			let rad   = angle * (Math.PI / 180);
			let pos_x = x + Math.cos(rad) * radius;
			let pos_y = y + Math.sin(rad) * radius;

			callback(pos_x, pos_y, radius, angle);

		}

	}

};
