
import { eyes } from "./eyes.mjs";

export const DrawEyePupil = (ctx, side, position, feeling) => {

	let eye = eyes[side] || null;
	if (eye !== null) {

		if (typeof position["x"] === "number" && typeof position["y"] === "number") {

			let delta_x = position["x"] - eye["ball"]["x"];
			let delta_y = position["y"] - eye["ball"]["y"];
			let radian  = Math.atan2(delta_y, delta_x);
			let radius  = Math.min(eye["ball"]["r"] - eye["pupil"]["r"] - 2, Math.sqrt(Math.pow(delta_x, 2) + Math.pow(delta_y, 2)));

			if (feeling === "angry") {
				radius *= 0.6;
			}

			let pupil_x = eye.ball.x + Math.cos(radian) * radius;
			let pupil_y = eye.ball.y + Math.sin(radian) * radius;

			eye["pupil"]["x"] = pupil_x;
			eye["pupil"]["y"] = pupil_y;

		}

		ctx.beginPath();
		ctx.arc(
			eye["pupil"]["x"],
			eye["pupil"]["y"],
			eye["pupil"]["r"],
			0,
			Math.PI * 2
		);
		ctx.fillStyle = "#000000";
		ctx.fill();
		ctx.closePath();

	}

};

