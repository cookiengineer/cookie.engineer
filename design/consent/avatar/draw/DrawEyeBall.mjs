
import { eyes } from "./eyes.mjs";

export const DrawEyeBall = (ctx, side, position, feeling) => {

	let eye = eyes[side] || null;
	if (eye !== null) {

		let dist = 128;

		if (typeof position["x"] === "number" && typeof position["y"] === "number") {
			dist = Math.sqrt(Math.pow(eye["ball"]["x"] - position["x"], 2) + Math.pow(eye["ball"]["y"] - position["y"], 2), 2);
		}

		if (feeling === "angry") {

			if (dist > 128) {
				dist = 128;
			}

			ctx.beginPath();
			ctx.ellipse(
				eye["ball"]["x"],
				eye["ball"]["y"],
				eye["ball"]["r"],
				eye["ball"]["r"] * 0.6 - eye["ball"]["r"] * 0.15 * (1 - (dist / 128)),
				0,
				0,
				Math.PI * 2
			);
			ctx.fillStyle = "#ffffff";
			ctx.fill();
			ctx.closePath();

		} else if (dist < 128) {

			if (dist > 128) {
				dist = 128;
			}

			ctx.beginPath();
			ctx.ellipse(
				eye["ball"]["x"],
				eye["ball"]["y"],
				eye["ball"]["r"],
				eye["ball"]["r"] - eye["ball"]["r"] * 0.15 * (1 - (dist / 128)),
				0,
				0,
				Math.PI * 2
			);
			ctx.fillStyle = "#ffffff";
			ctx.fill();
			ctx.closePath();

		} else {

			ctx.beginPath();
			ctx.arc(
				eye["ball"]["x"],
				eye["ball"]["y"],
				eye["ball"]["r"],
				0,
				Math.PI * 2
			);
			ctx.fillStyle = "#ffffff";
			ctx.fill();
			ctx.closePath();

		}

	}

};

