
export const DrawSpeechHelper = (ctx, scale, position_x, color) => {

	let text = ((position_x / scale) | 0) + "ms";

	ctx.fillStyle = color;
	ctx.strokeStyle = color;
	ctx.beginPath();
	ctx.moveTo(position_x, 0);
	ctx.lineTo(position_x, 128);
	ctx.fillText(text, position_x + 4, 16);
	ctx.stroke();
	ctx.closePath();

};

