
export const DrawWorldModel = (ctx, delta, world_width, world_height) => {

	ctx.lineWidth = 4;
	ctx.strokeStyle = "#ffff00";
	ctx.beginPath();

	// Left Edge
	ctx.moveTo((-world_width / 2) + 2, (-world_height / 2));
	ctx.lineTo((-world_width / 2) + 2, (+world_height / 2));

	// Right Edge
	ctx.moveTo((+world_width / 2) - 2, (-world_height / 2));
	ctx.lineTo((+world_width / 2) - 2, (+world_height / 2));

	ctx.stroke();
	ctx.closePath();

};
