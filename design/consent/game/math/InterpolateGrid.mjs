
export const InterpolateGrid = (width, from_x, from_y, to_x, to_y, step, callback) => {

	step     = typeof step === "number"       ? Math.abs(step) : 16;
	callback = typeof callback === "function" ? callback       : null;

	if (callback !== null) {

		if (from_x < to_x) {

			if (from_y < to_y) {

				for (let x = from_x; x <= to_x; x += step) {

					if (x >= 0 && x <= width) {

						for (let y = from_y; y <= to_y; y += step) {
							callback(x | 0, y | 0);
						}

					}

				}

			} else if (from_y > to_y) {

				for (let x = from_x; x <= to_x; x += step) {

					if (x >= 0 && x <= width) {

						for (let y = from_y; y >= to_y; y -= step) {
							callback(x | 0, y | 0);
						}

					}

				}

			} else if (from_y == to_y) {

				for (let x = from_x; x <= to_x; x += step) {

					if (x >= 0 && x <= width) {
						callback(x | 0, from_y | 0);
					}

				}

			}

		} else if (from_x > to_x) {

			if (from_y < to_y) {

				for (let x = from_x; x >= to_x; x -= step) {

					if (x >= 0 && x <= width) {

						for (let y = from_y; y <= to_y; y += step) {
							callback(x | 0, y | 0);
						}

					}

				}

			} else if (from_y > to_y) {

				for (let x = from_x; x >= to_x; x -= step) {

					if (x >= 0 && x <= width) {

						for (let y = from_y; y >= to_y; y -= step) {
							callback(x | 0, y | 0);
						}

					}

				}

			} else if (from_y == to_y) {

				for (let x = from_x; x >= to_x; x -= step) {

					if (x >= 0 && x <= width) {
						callback(x | 0, from_y | 0);
					}

				}

			}

		} else if (from_x == to_x) {

			if (from_y < to_y) {

				for (let y = from_y; y <= to_y; y += step) {
					callback(from_x | 0, y | 0);
				}

			} else if (from_y > to_y) {

				for (let y = from_y; y >= to_y; y -= step) {
					callback(from_x | 0, y | 0);
				}

			} else if (from_y == to_y) {
				callback(from_x | 0, from_y | 0);
			}

		}

	}

};

