
import { EaseOut          } from "../math/EaseOut.mjs";
import { InterpolateColor } from "../math/InterpolateColor.mjs";
import { Palette          } from "../Palette.mjs";

export const DrawFace = (ctx, width, height, feeling, statemap) => {

	let radius = Math.min(width, height) / 2;

	ctx.clearRect(0, 0, width, height);

	if (feeling === "okay") {

		let color = Palette["okay"];

		ctx.beginPath();
		ctx.arc(width / 2 | 0, height / 2 | 0, radius | 0, 0, Math.PI * 2);
		ctx.fillStyle = "rgb(" + color[0] + "," + color[1] + "," + color[2] + ")";
		ctx.fill();
		ctx.closePath();

	} else if (feeling === "sick") {

		let f = 1.0;

		if (typeof statemap["nausea"] === "number") {
			f = EaseOut(statemap["nausea"] / 100);
		}

		if (f > 1.0) {
			f = 1.0;
		}

		let color = InterpolateColor(Palette["okay"], Palette["sick"], f);

		ctx.beginPath();
		ctx.arc(width / 2 | 0, height / 2 | 0, radius | 0, 0, Math.PI * 2);
		ctx.fillStyle = "rgb(" + color[0] + "," + color[1] + "," + color[2] + ")";
		ctx.fill();
		ctx.closePath();

	} else if (feeling === "vomit") {

		let f1 = 1.0;

		if (typeof statemap["start"] === "number" && typeof statemap["end"] === "number") {

			let dt = Date.now() - statemap["start"];

			f1 = dt / (statemap["end"] - statemap["start"]);

		} else if (typeof statemap["start"] === "number") {

			let dt = Date.now() - statemap["start"];
			let t  = dt / 250;

			if (t > 1.0) {
				f1 = 1.0;
			} else {
				f1 = t;
			}

		}

		let f2    = EaseOut(f1);
		let color = InterpolateColor(Palette["sick"], Palette["okay"], f2);

		ctx.beginPath();
		ctx.arc(width / 2 | 0, height / 2 | 0, radius | 0, 0, Math.PI * 2);
		ctx.fillStyle = "rgb(" + color[0] + "," + color[1] + "," + color[2] + ")";
		ctx.fill();
		ctx.closePath();

	} else if (feeling === "angry") {

		let f1 = 1.0;

		if (typeof statemap["start"] === "number" && typeof statemap["end"] === "number") {

			let dt = Date.now() - statemap["start"];

			// TODO: This is wrong, it should be something like:
			// - within the 250ms, interpolate towards angry
			// - after first second, stay angry until end - 250ms
			// - after end - 250ms, interpolate towards okay
			f1 = dt / (statemap["end"] - statemap["start"]);

		} else if (typeof statemap["start"] === "number") {

			let dt = Date.now() - statemap["start"];
			let t  = dt / 250;

			if (t > 1.0) {
				f1 = 0.5;
			} else {
				f1 = t / 2;
			}

		}

		if (f1 <= 0.5) {

			let f2    = EaseOut(f1 * 2);
			let color = InterpolateColor(Palette["okay"], Palette["angry"], f2);

			ctx.beginPath();
			ctx.arc(width / 2 | 0, height / 2 | 0, radius | 0, 0, Math.PI * 2);
			ctx.fillStyle = "rgb(" + color[0] + "," + color[1] + "," + color[2] + ")";
			ctx.fill();
			ctx.closePath();

		} else if (f1 > 0.5 && f1 < 1.0) {

			let f2    = EaseOut((f1 - 0.5) * 2);
			let color = InterpolateColor(Palette["angry"], Palette["okay"], f2);

			ctx.beginPath();
			ctx.arc(width / 2 | 0, height / 2 | 0, radius | 0, 0, Math.PI * 2);
			ctx.fillStyle = "rgb(" + color[0] + "," + color[1] + "," + color[2] + ")";
			ctx.fill();
			ctx.closePath();

		} else {

			let color = Palette["angry"];

			ctx.beginPath();
			ctx.arc(width / 2 | 0, height / 2 | 0, radius | 0, 0, Math.PI * 2);
			ctx.fillStyle = "rgb(" + color[0] + "," + color[1] + "," + color[2] + ")";
			ctx.fill();
			ctx.closePath();

		}

	} else if (feeling !== "") {

		let color = Palette["okay"];

		ctx.beginPath();
		ctx.arc(width / 2 | 0, height / 2 | 0, radius | 0, 0, Math.PI * 2);
		ctx.fillStyle = "rgb(" + color[0] + "," + color[1] + "," + color[2] + ")";
		ctx.fill();
		ctx.closePath();

	}

};
