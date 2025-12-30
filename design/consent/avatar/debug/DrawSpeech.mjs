
export const DrawSpeech = (ctx, identifier, scale, speech, duration) => {

	let text = "Speech: " + identifier;

	let length = ((duration * 1000) | 0);
	if (speech["length"] != length) {
		text += " " + speech["length"] + "ms != " + length + "ms";
	}

	ctx.font = "16px vera-mono";
	ctx.fillStyle = "#0f99cb";
	ctx.fillText(text, 4, 16);

	speech["phonemes"].forEach((phoneme, p) => {

		let pos_x = speech["timeline"][p] * scale;
		let pos_y = (96 / 2) + 8;

		if (phoneme === "") {

			ctx.font = "16px vera-mono";
			ctx.fillStyle = "#ffffff";
			ctx.fillText("|", pos_x - 5, pos_y);

		} else if (p < speech["phonemes"].length - 1) {

			ctx.font = "16px vera-mono";
			ctx.fillStyle = "#ffffff";

			let next_x   = scale * speech["timeline"][p + 1];
			let center_x = pos_x + ((next_x - pos_x) / 2);

			ctx.fillText("|", pos_x - 5, pos_y);
			ctx.fillText(phoneme, center_x, pos_y);

		} else {

			ctx.font = "16px vera-mono";
			ctx.fillStyle = "#ffffff";

			let next_x   = scale * speech["length"];
			let center_x = pos_x + ((next_x - pos_x) / 2);

			ctx.fillText("|", pos_x - 5, pos_y);
			ctx.fillText(phoneme, center_x, pos_y);

		}

	});

};

