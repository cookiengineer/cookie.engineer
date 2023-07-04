$.extend(z.Benchmark.prototype, {


	setSpritePosition: function(object, time) {


		// Hint: The sprite is linked. Changing properties on the sprite
		// will change it for all objects having the same sprite attached.


		// There seems to be an issue when using +new Date() within the
		// same callstack. The compiler seems to optimize it somehow
		// with some stupid magic. This fixes garbage collector issues.

		if (!object.spriteStartTime) {
			object.randomDelta = Math.random() * 1000;
			object.spriteStartTime = time;
		}

		var sprite = object.sprite,
			currentFrame = Math.floor(((time + object.randomDelta - object.spriteStartTime) % ( 1000 * (sprite.frames / sprite.fps) )) / (1000 / sprite.fps) );


		if (currentFrame !== object.currentFrame) {

			object.currentFrame = currentFrame;

			var posX = (currentFrame % sprite.frameColumns) * object.width,
				posY = Math.floor(currentFrame / sprite.frameColumns) * object.height;

			if (object.spriteNode) {
				object.spriteNode.style[z.css.transform] = 'translate3d(-' + posX + 'px, -' + posY + 'px, 0px)';
			} else {
				object.node.style.backgroundPosition = '-' + posX + 'px -' + posY + 'px';
			}
		}

	},


	/*
	 * This function sets the actual position of an object with a given mode.
	 * @param {Object} object The actual object which has an attached node
	 */
	setPosition: function(object) {

		var node = object.node,
			type = this.options.type,
			method = this.options.position,
			_x = object.position.x,
			_y = object.position.y,
			_z = object.position.z,
			direction = object.direction;


		// calculate the change
		direction.x = _x + object.width >= this.width ? -1 : (_x <= 0 ? 1 : direction.x);
		direction.y = _y + object.height >= this.height ? -1 : (_y <= 0 ? 1 : direction.y);
		direction.z = _z > this.depth ? -1 : (_z <= 0 ? 1 : direction.z);

		_x += object.speed.x * direction.x;
		_y += object.speed.y * direction.y;
		_z += object.speed.z * direction.z;


		// update the position
		object.position = {
			x: _x,
			y: _y,
			z: _z
		};


		// round everything
		_x = Math.round(_x);
		_y = Math.round(_y);
		_z = Math.round(_z);
		// _x = _x + 0.5 | null;
		// _y = _y + 0.5 | null;
		// _z = _z + 0.5 | null;

		// apply the change
		switch(method) {

			case 'lefttop-xy':
				node.style.left = _x + 'px';
				node.style.top = _y + 'px';
				break;

			case 'lefttop-xyz':
				node.style.left = _x + 'px';
				node.style.top = _y + 'px';
				node.style.zIndex = _z;
				break;

			case 'translate-xy':
				node.style[z.css.transform] = 'translate(' + _x + 'px, ' + _y + 'px)';
				break;

			case 'translate-xyz':
				node.style[z.css.transform] = 'translate(' + _x + 'px, ' + _y + 'px)';
				node.style.zIndex = _z;
				break;

			case 'translate3d-xy':
				node.style[z.css.transform] = 'translate3d(' + _x + 'px, ' + _y + 'px, 0)';
				break;

			case 'translate3d-xyz':
				node.style[z.css.transform] = 'translate3d(' + _x + 'px, ' + _y + 'px, ' + _z + 'px)';
				break;

			case 'translate3d-xyz2':
				node.style[z.css.transform] = 'translate3d(' + _x + 'px, ' + _y + 'px, 0)';
				node.style.zIndex = _z;
				break;


		}

	},

	resetPosition: function() {

		var nodes = this.dynamicNodes;

		for (var n = 0, l = nodes.length; n < l; n++) {
			nodes[n].node.style.top = '';
			nodes[n].node.style.left = '';
			nodes[n].node.style.zIndex = '';
			nodes[n].node.style[z.css.transform] = '';
		}

	}

});
