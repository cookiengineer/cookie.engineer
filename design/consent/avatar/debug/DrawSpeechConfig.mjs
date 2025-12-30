
export const DrawSpeechConfig = (ctx, identifier, scale, speech, config) => {

	config["sentence"].forEach((word, s) => {

		let pos_x = scale * config["timeline"][s];
		let pos_y = 128 - 32;

		if (word === "." || word === "?" || word === "!") {

			ctx.font = "16px vera-mono";
			ctx.fillStyle = "#0f99cb";
			ctx.fillText("|", pos_x - 5, pos_y);

		} else if (s < config["sentence"].length - 1) {

			ctx.font = "16px vera-mono";

			let text_metrics = ctx.measureText(word);
			let next_x       = scale * config["timeline"][s + 1];
			let center_x     = pos_x + ((next_x - pos_x) / 2) - (text_metrics.width / 2);

			ctx.fillStyle = "#0f99cb";
			ctx.fillText("|", pos_x - 5, pos_y);

			ctx.fillStyle = "#ffffff";
			ctx.fillText(word, center_x, pos_y);

		} else {

			ctx.font = "16px vera-mono";

			let text_metrics = ctx.measureText(word);
			let next_x       = scale * config["length"];
			let center_x     = pos_x + ((next_x - pos_x) / 2) - (text_metrics.width / 2);

			ctx.fillStyle = "#0f99cb";
			ctx.fillText("|", pos_x - 5, pos_y);

			ctx.fillStyle = "#ffffff";
			ctx.fillText(word, center_x, pos_y);

		}

	});

	config["timeline"].forEach((time, t) => {

		let pos_x = scale * config["timeline"][t];
		let pos_y = 128 - 8;
		let text  = (time).toString();

		ctx.font = "16px vera-mono";

		let text_metrics = ctx.measureText(text);

		ctx.fillStyle = "#0f99cb";
		ctx.fillText(text, pos_x - (text_metrics.width / 2), pos_y);

	});

};

