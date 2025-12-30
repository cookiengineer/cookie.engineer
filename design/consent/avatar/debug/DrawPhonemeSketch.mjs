
import { PhonemeSketch } from "./PhonemeSketch.mjs";

export const DrawPhonemeSketch = (ctx, image, phoneme, mouth) => {

	let frame = PhonemeSketch[phoneme] || null;
	if (frame !== null) {

		// 170 to right, 32 to bottom is mouth difference
		let angle = Math.atan2(32, 170);

		ctx.globalAlpha = 0.5;
		ctx.save();
		ctx.translate(mouth.x, mouth.y);
		ctx.rotate(angle);
		ctx.drawImage(
			image,
			frame.x - frame.w / 2,
			frame.y - frame.h / 2,
			frame.w,
			frame.h,
			-frame.w / 2,
			-frame.h / 2,
			frame.w,
			frame.h
		);
		ctx.restore();
		ctx.globalAlpha = 1.0;

	}

};
