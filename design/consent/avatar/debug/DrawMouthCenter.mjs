
export const DrawMouthCenter = (ctx, position) => {

	ctx.fillStyle = "#ff0000";
	ctx.beginPath();
	ctx.arc(position.x, position.y, 5, 0, 2 * Math.PI);
	ctx.fill();
	ctx.closePath();

}

