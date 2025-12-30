
import { DrawBezierCurve        } from "./DrawBezierCurve.mjs";
import { EaseOut                } from "../math/EaseOut.mjs";
import { InterpolateBezierCurve } from "../math/InterpolateBezierCurve.mjs";
import { Expressions            } from "../mouth/Expressions.mjs";
import { Phonemes               } from "../mouth/Phonemes.mjs";

export const DrawMouthPhoneme = (ctx, phoneme, statemap, debug) => {

	debug = typeof debug === "boolean" ? debug : false;

	if (statemap["start"] !== null && statemap["speech"] !== null) {

		let dt            = Date.now() - statemap["start"];
		let phoneme_start = statemap["speech"]["timeline"][statemap["index"]];
		let phoneme_end   = statemap["speech"]["timeline"][statemap["index"] + 1] || statemap["speech"]["length"];
		let phoneme_next  = statemap["speech"]["phonemes"][statemap["index"] + 1] || "";

		let t = (dt - phoneme_start) / (phoneme_end - phoneme_start);
		if (t < 0.0) {
			t = 0.0;
		}

		let bezier1 = Phonemes[phoneme]      || Expressions["okay"];
		let bezier2 = Phonemes[phoneme_next] || Expressions["okay"];

		if (debug === true) {
			ctx.globalAlpha = 0.5;
		}

		for (let c = 0; c < 2; c++) {

			let curve = InterpolateBezierCurve(bezier1[c], bezier2[c], t);

			ctx.beginPath();
			ctx.moveTo(curve.start.x, curve.start.y);
			ctx.fillStyle = "#000000";
			ctx.bezierCurveTo(
				curve.cp1.x,
				curve.cp1.y,
				curve.cp2.x,
				curve.cp2.y,
				curve.end.x,
				curve.end.y
			);
			ctx.fill();
			ctx.closePath();

		}

		if (debug === true) {

			ctx.globalAlpha = 1.0;

			for (let c = 0; c < 2; c++) {
				DrawBezierCurve(ctx, InterpolateBezierCurve(bezier1[c], bezier2[c], t));
			}

			ctx.font = "32px vera-mono";

			let text_metrics = ctx.measureText(phoneme);
			let text_x       = 115 - (text_metrics.width / 2);
			let text_y       = 180;

			ctx.fillStyle = "#ffffff";
			ctx.fillText(phoneme, text_x, text_y);

		}

	} else if (statemap["start"] === null && statemap["speech"] === null) {

		let beziers = Phonemes[phoneme] || null;
		if (beziers !== null) {

			if (debug === true) {
				ctx.globalAlpha = 0.5;
			}

			beziers.forEach((curve) => {

				ctx.beginPath();
				ctx.moveTo(curve.start.x, curve.start.y);
				ctx.fillStyle = "#000000";
				ctx.bezierCurveTo(
					curve.cp1.x,
					curve.cp1.y,
					curve.cp2.x,
					curve.cp2.y,
					curve.end.x,
					curve.end.y
				);
				ctx.fill();
				ctx.closePath();

			});

			if (debug === true) {

				ctx.globalAlpha = 1.0;

				beziers.forEach((curve) => {
					DrawBezierCurve(ctx, curve);
				});

			}

		}

	}

};
