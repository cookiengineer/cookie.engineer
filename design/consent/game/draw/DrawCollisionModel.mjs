
export const DrawCollisionModel = (ctx, delta, entity) => {

	if (typeof entity.radius === "number") {

		ctx.lineWidth = 1;
		ctx.strokeStyle = "#00ff00";
		ctx.beginPath();
		ctx.arc(entity.position.x, entity.position.y, entity.radius, 0, Math.PI * 2);
		ctx.stroke();
		ctx.closePath();

	} else if (typeof entity.width === "number" && typeof entity.height === "number") {

		ctx.lineWidth = 1;
		ctx.strokeStyle = "#00ff00";
		ctx.strokeRect(
			entity.position.x - entity.width / 2,
			entity.position.y - entity.height / 2,
			entity.width,
			entity.height
		);

	}

};
