
export const DrawPhonemeRuler = (ctx, scale, position1, position2, color0, color1, color2) => {

	let position_x1 = (position1.x * scale) | 0;
	let position_y1 = (position1.y * scale) | 0;
	let position_x2 = (position2.x * scale) | 0;
	let position_y2 = (position2.y * scale) | 0;

	if (position_x2 < position_x1) {
		position_x2 = (position1.x * scale) | 0;
		position_x1 = (position2.x * scale) | 0;
	}

	if (position_y2 < position_y1) {
		position_y2 = (position1.y * scale) | 0;
		position_y1 = (position2.y * scale) | 0;
	}

	ctx.strokeStyle = color0;
	ctx.beginPath();
	ctx.moveTo(position_x1, position_y1);
	ctx.lineTo(position_x2, position_y1);
	ctx.lineTo(position_x2, position_y2);
	ctx.lineTo(position_x1, position_y2);
	ctx.lineTo(position_x1, position_y1);
	ctx.stroke();
	ctx.closePath();

	ctx.font = "16px vera-mono";

	let text0         = (Math.abs(position_x2 - position_x1) | 0) + "x" + (Math.abs(position_y2 - position_y1) | 0);
	let text0_metrics = ctx.measureText(text0);
	let text0_x       = position_x1 + (Math.abs(position_x2 - position_x1) / 2) - (text0_metrics.width / 2);
	let text0_y       = position_y1 + (Math.abs(position_y2 - position_y1) / 2);

	ctx.fillStyle = color0;
	ctx.fillText(text0, text0_x, text0_y);

	let text1         = position_x1 + "x" + position_y1;
	let text1_metrics = ctx.measureText(text1);
	let text1_x       = position_x1 - (text1_metrics.width / 2);
	let text1_y       = position_y1 - 8;

	ctx.fillStyle = color1;
	ctx.fillText(text1, text1_x, text1_y);

	let text2         = position_x2 + "x" + position_y2;
	let text2_metrics = ctx.measureText(text2);
	let text2_x       = position_x2 - (text2_metrics.width / 2);
	let text2_y       = position_y2 - 32;

	ctx.fillStyle = color2;
	ctx.fillText(text2, text2_x, text2_y);

};
