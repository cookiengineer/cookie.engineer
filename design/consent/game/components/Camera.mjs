
export const Camera = function(player) {

	this.player   = player;
	this.width    = 0;
	this.height   = 0;
	this.position = {
		x: 0,
		y: 0
	};

	this.world = {
		width:  1280,
		height: 960
	};

};

Camera.prototype = {

	ResizeTo: function(screen_width, screen_height) {

		if (screen_width >= 1280) {

			this.width  = screen_width;
			this.height = screen_height;

			this.world.width  = screen_width;
			this.world.height = screen_height;

		} else {

			this.width  = screen_width;
			this.height = screen_height;

			this.world.width  = 1280;
			this.world.height = screen_height;

		}

	},

	Update: function(delta) {

		if (this.width >= this.world.width) {

			this.position.x = 0;

		} else {

			let target_x    = this.player.position.x;
			let world_min_x = (-this.world.width / 2);
			let world_max_x = (+this.world.width / 2)
			let min_x       = world_min_x + (this.width / 2);
			let max_x       = world_max_x - (this.width / 2);

			target_x = Math.min(target_x, max_x);
			target_x = Math.max(min_x, target_x);

			this.position.x += (target_x - this.position.x) * 0.15;

		}

	}

};
