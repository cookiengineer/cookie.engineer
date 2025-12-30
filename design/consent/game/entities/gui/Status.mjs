
import { GetImage } from "../../../common/image/GetImage.mjs";

const draw_bar = function(ctx, type, x1, y1, progress, width) {

	let src_y = type * 16;
	let bar_w = progress * (width - 16) | 0;

	// left edge
	ctx.drawImage(
		this.image,
		64,
		src_y,
		8,
		16,
		x1,
		y1,
		8,
		16
	);

	// center
	ctx.drawImage(
		this.image,
		72,
		src_y,
		16,
		16,
		x1 + 8,
		y1,
		bar_w,
		16
	);

	// right edge
	ctx.drawImage(
		this.image,
		88,
		src_y,
		8,
		16,
		x1 + 8 + bar_w,
		y1,
		8,
		16
	);

};

const draw_label = function(ctx, label, x1, y1, width) {

	ctx.font = "16px vera-mono";

	let text_metrics = ctx.measureText(label);
	let pos_x = x1 + (width / 2) - (text_metrics.width / 2);
	let pos_y = y1;

	ctx.textBaseline = "top";
	ctx.fillStyle = "#000000";
	ctx.fillText(label, pos_x, pos_y);

};

export const Status = function() {

	this.image = GetImage("gui/Status");

	this.width    = 196;
	this.height   = 32 + (2 * 16) + (1 * 8);
	this.position = {
		x: 0,
		y: 0
	};

	this.statistics = {
		health:   0.0,
		progress: 0.0
	};

};

Status.prototype = {

	Render: function(ctx, delta) {

		ctx.globalAlpha = 1.0;

		let top    = this.position.y - this.height / 2;
		let left   = this.position.x - this.width  / 2;
		let bottom = this.position.y + this.height / 2;
		let right  = this.position.x + this.width  / 2;

		// top left
		ctx.drawImage(
			this.image,
			0,
			0,
			16,
			16,
			left,
			top,
			16,
			16
		);

		// top edge
		ctx.drawImage(
			this.image,
			16,
			0,
			32,
			16,
			left + 16,
			top,
			this.width - 32,
			16
		);

		// top right
		ctx.drawImage(
			this.image,
			48,
			0,
			16,
			16,
			right - 16,
			top,
			16,
			16
		);

		// right edge
		ctx.drawImage(
			this.image,
			48,
			16,
			16,
			32,
			right - 16,
			top + 16,
			16,
			this.height - 32
		);

		// bottom right
		ctx.drawImage(
			this.image,
			48,
			48,
			16,
			16,
			right - 16,
			bottom - 16,
			16,
			16
		);

		// bottom edge
		ctx.drawImage(
			this.image,
			16,
			48,
			32,
			16,
			left + 16,
			bottom - 16,
			this.width - 32,
			16
		);

		// bottom left
		ctx.drawImage(
			this.image,
			0,
			48,
			16,
			16,
			left,
			bottom - 16,
			16,
			16
		);

		// left edge
		ctx.drawImage(
			this.image,
			0,
			16,
			16,
			32,
			left,
			top + 16,
			16,
			this.height - 32
		);

		// content box
		ctx.drawImage(
			this.image,
			16,
			16,
			32,
			32,
			left + 16,
			top + 16,
			this.width - 32,
			this.height - 32
		);

		let health_value   = (this.statistics.health / 100.0);
		let progress_value = (this.statistics.progress / 100.0);

		draw_label.call(this, ctx, "Health", left + 16, top + 17, this.width - 32);
		draw_bar.call(this, ctx, 0, left + 16, top + 16, 1.0, this.width - 32);
		draw_bar.call(this, ctx, 1, left + 16, top + 16, health_value, this.width - 32);

		draw_label.call(this, ctx, "Progress", left + 16, top + 41, this.width - 32);
		draw_bar.call(this, ctx, 0, left + 16, top + 40, 1.0, this.width - 32);
		draw_bar.call(this, ctx, 2, left + 16, top + 40, progress_value, this.width - 32);

		ctx.globalAlpha = 1.0;

	},

	SetPosition: function(x, y) {

		x = typeof x === "number" ? x : this.position.x;
		y = typeof y === "number" ? y : this.position.y;

		this.position.x = x;
		this.position.y = y;

	},

	Update: function(delta, width, height) {

		// Do Nothing

	},

	UpdateInfo: function(health, progress) {

		this.statistics.health   = health;
		this.statistics.progress = progress;

	}

};
