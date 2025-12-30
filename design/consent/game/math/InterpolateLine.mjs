
export const InterpolateLine = (width, from_x, from_y, to_x, to_y, step, callback) => {

	step     = typeof step === "number"       ? Math.abs(step) : 16;
	callback = typeof callback === "function" ? callback       : null;

	if (callback !== null) {

		let dx = to_x - from_x;
		let dy = to_y - from_y;

		let distance = Math.hypot(dx, dy);

		if (distance <= step) {

			callback(from_x | 0, from_y | 0);

		} else {

			let steps = Math.ceil(distance / step);

			for (let s = 0; s <= steps; s++) {

				let f = s / steps;
				let x = from_x + dx * f;
				let y = from_y + dy * f;

				callback(x | 0, y | 0);

			}

		}

	}

};

