export const DrawPhonemeTimeline = (ctx, scale, timeline, canvasHeight = 64) => {

	// Draw features first as overlay lines
	timeline.forEach((segment) => {

		if (!segment.features) return;

		ctx.lineWidth = 1;

		// Energy line (yellow)
		ctx.beginPath();
		ctx.strokeStyle = "#ffff00";
		segment.features.forEach((f, i) => {
			const x = f.time * scale;
			const y = canvasHeight - f.energy * canvasHeight; // invert
			if (i === 0) ctx.moveTo(x, y);
			else ctx.lineTo(x, y);
		});
		ctx.stroke();
		ctx.closePath();

		// ZCR line (green)
		ctx.beginPath();
		ctx.strokeStyle = "#00ff00";
		segment.features.forEach((f, i) => {
			const x = f.time * scale;
			const y = canvasHeight - f.zcr * canvasHeight;
			if (i === 0) ctx.moveTo(x, y);
			else ctx.lineTo(x, y);
		});
		ctx.stroke();
		ctx.closePath();

		// Centroid line (blue-ish, normalized)
		const maxCentroid = 5000; // adjust if your speech has higher frequencies
		ctx.beginPath();
		ctx.strokeStyle = "#ffffff";
		segment.features.forEach((f, i) => {
			const x = f.time * scale;
			const y = canvasHeight - Math.min(f.centroid / maxCentroid, 1) * canvasHeight;
			if (i === 0) ctx.moveTo(x, y);
			else ctx.lineTo(x, y);
		});
		ctx.stroke();
		ctx.closePath();

	});

	// Draw phoneme boundaries on top
	timeline.forEach((segment) => {
		segment.phonemes.forEach((phoneme) => {

			let pos_x1 = (phoneme.start * scale) | 0;

			ctx.beginPath();
			ctx.strokeStyle = "#ff00ff"; // bright magenta for boundaries
			ctx.moveTo(pos_x1, 0);
			ctx.lineTo(pos_x1, canvasHeight);
			ctx.stroke();
			ctx.closePath();

		});
	});
};
