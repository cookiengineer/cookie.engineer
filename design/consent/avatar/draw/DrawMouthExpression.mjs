
import { DrawBezierCurve        } from "./DrawBezierCurve.mjs";
import { EaseOut                } from "../math/EaseOut.mjs";
import { InterpolateBezierCurve } from "../math/InterpolateBezierCurve.mjs";
import { Expressions            } from "../mouth/Expressions.mjs";

export const DrawMouthExpression = (ctx, feeling, statemap, debug) => {

	debug = typeof debug === "boolean" ? debug : false;

	if (feeling === "") {
		feeling = "okay";
	}

	if (feeling === "okay" || feeling === "sick") {

		let f = 0.0;

		if (typeof statemap["nausea"] === "number") {
			f = EaseOut(statemap["nausea"] / 100);
		}

		if (f > 1.0) {
			f = 1.0;
		}

		if (debug === true) {
			ctx.globalAlpha = 0.5;
		}

		for (let c = 0; c < Expressions["okay"].length; c++) {

			let curve = InterpolateBezierCurve(Expressions["okay"][c], Expressions["sick"][c], f);

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

			for (let c = 0; c < Expressions["okay"].length; c++) {
				DrawBezierCurve(ctx, InterpolateBezierCurve(Expressions["okay"][c], Expressions["sick"][c], f));
			}

		}

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

		let f2 = EaseOut(f1);

		if (debug === true) {
			ctx.globalAlpha = 0.5;
		}

		for (let c = 0; c < Expressions["okay"].length; c++) {

			let curve = InterpolateBezierCurve(Expressions["sick"][c], Expressions["okay"][c], f2);

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

			for (let c = 0; c < Expressions["okay"].length; c++) {
				DrawBezierCurve(ctx, InterpolateBezierCurve(Expressions["sick"][c], Expressions["okay"][c], f2));
			}

		}

	} else if (feeling === "angry") {

		let f1 = 1.0;

		if (typeof statemap["start"] === "number" && typeof statemap["end"] === "number") {

			let dt = Date.now() - statemap["start"];

			f1 = dt / (statemap["end"] - statemap["start"]);

		} else if (typeof statemap["start"] === "number") {

			// EaseIn from 0ms to 250ms, then stay angry
			let dt = Date.now() - statemap["start"];
			let t = dt / 250;

			if (t > 1.0) {
				f1 = 0.5;
			} else {
				f1 = t / 2;
			}

		}

		if (f1 <= 0.5) {

			let f2 = EaseOut(f1 * 2);

			if (debug === true) {
				ctx.globalAlpha = 0.5;
			}

			for (let c = 0; c < Expressions["okay"].length; c++) {

				let curve = InterpolateBezierCurve(Expressions["okay"][c], Expressions["angry"][c], f2);

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

				for (let c = 0; c < Expressions["okay"].length; c++) {
					DrawBezierCurve(ctx, InterpolateBezierCurve(Expressions["okay"][c], Expressions["angry"][c], f2));
				}

			}

		} else if (f1 >= 0.5 && f1 <= 1.0) {

			let f2 = EaseOut((f1 - 0.5) * 2);

			if (debug === true) {
				ctx.globalAlpha = 0.5;
			}

			for (let c = 0; c < Expressions["okay"].length; c++) {

				let curve = InterpolateBezierCurve(Expressions["angry"][c], Expressions["okay"][c], f2);

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

				for (let c = 0; c < Expressions["okay"].length; c++) {
					DrawBezierCurve(ctx, InterpolateBezierCurve(Expressions["angry"][c], Expressions["okay"][c], f2));
				}

			}

		} else {

			if (debug === true) {
				ctx.globalAlpha = 0.5;
			}

			Expressions["angry"].forEach((curve) => {

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

				Expressions["angry"].forEach((curve) => {
					DrawBezierCurve(ctx, curve);
				});

			}

		}

	} else if (feeling !== "") {

		let beziers = Expressions[feeling] || null;
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

