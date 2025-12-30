
export const Camera = function(player) {

	this.player = player;
	this.position = {
		x: 0,
		y: 0
	};
	this.screen = {
		width:  0,
		height: 0
	};

	this.min_width = 1280;

};

Camera.prototype = {

	Update: function(delta, world_width, world_height) {

		if (this.screen.width >= this.min_width) {

			this.position.x = 0;

		} else {

			let target_x    = this.player.position.x;
			let world_min_x = (-this.min_width / 2);
			let world_max_x = (+this.min_width / 2)
			let min_x       = world_min_x + (this.screen.width / 2);
			let max_x       = world_max_x - (this.screen.width / 2);

			target_x = Math.min(target_x, max_x);
			target_x = Math.max(min_x, target_x);

			this.position.x += (target_x - this.position.x) * 0.15;

		}

	}

};
