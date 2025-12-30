
export const DrawPhonemeHelper = (ctx, scale, position, color) => {

	let position_x = (position.x * scale) | 0;
	let position_y = (position.y * scale) | 0;

	ctx.fillStyle = color;
	ctx.beginPath();
	ctx.arc(position_x, position_y, 2, 0, 2 * Math.PI);
	ctx.fill();
	ctx.closePath();

	ctx.font = "16px vera-mono";

	let text         = position_x + "x" + position_y;
	let text_metrics = ctx.measureText(text);
	let text_x       = position_x - (text_metrics.width / 2);
	let text_y       = position_y - 32;

	ctx.fillStyle = color;
	ctx.fillText(text, text_x, text_y);

};
