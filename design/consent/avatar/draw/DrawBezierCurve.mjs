
export const DrawBezierCurve = (ctx, curve) => {

	// start and end point
	ctx.fillStyle = "#ff0000";
	ctx.beginPath();
	ctx.arc(curve.start.x, curve.start.y, 5, 0, 2 * Math.PI);
	ctx.arc(curve.end.x, curve.end.y, 5, 0, 2 * Math.PI);
	ctx.fill();
	ctx.closePath();

	// control points
	ctx.fillStyle = "#00ff00";
	ctx.beginPath();
	ctx.arc(curve.cp1.x, curve.cp1.y, 5, 0, 2 * Math.PI);
	ctx.arc(curve.cp2.x, curve.cp2.y, 5, 0, 2 * Math.PI);
	ctx.fill();
	ctx.closePath();

	// anchor to control point 1
	ctx.strokeStyle = "#00ff00";
	ctx.beginPath();
	ctx.moveTo(curve.start.x, curve.start.y);
	ctx.lineTo(curve.cp1.x, curve.cp1.y);
	ctx.stroke();
	ctx.closePath();

	// anchor to control point 2
	ctx.strokeStyle = "#00ff00";
	ctx.beginPath();
	ctx.moveTo(curve.end.x, curve.end.y);
	ctx.lineTo(curve.cp2.x, curve.cp2.y);
	ctx.stroke();
	ctx.closePath();

	// bezier curve line
	ctx.beginPath();
	ctx.moveTo(curve.start.x, curve.start.y);
	ctx.strokeStyle = "#000000";
	ctx.bezierCurveTo(
		curve.cp1.x,
		curve.cp1.y,
		curve.cp2.x,
		curve.cp2.y,
		curve.end.x,
		curve.end.y
	);
	ctx.stroke();
	ctx.closePath();

};

