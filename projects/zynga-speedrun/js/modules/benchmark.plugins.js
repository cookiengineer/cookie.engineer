$.extend(z.Benchmark.prototype, {

	runPlugins: function(object) {

		// run node plugins
		this.plugins.nodecontent[this.options.nodecontent] && this.plugins.nodecontent[this.options.nodecontent].call(this, object);
		this.plugins.nodebackground[this.options.nodebackground] && this.plugins.nodebackground[this.options.nodebackground].call(this, object);

	},

	getRandomColor: function(alpha) {

		if (alpha === undefined) {
			var color = Math.round(0xffffff * Math.random()).toString(16);
			return '#' + (color.length === 5 ? '0' + color : color);
		} else {
			var r = Math.round(Math.random() * 255),
				g = Math.round(Math.random() * 255),
				b = Math.round(Math.random() * 255);

			return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
		}

	},

	getRandomImage: function(width, height, background, alpha) {

		var canvas = document.createElement('canvas'),
			context = canvas.getContext('2d');

		canvas.width = width;
		canvas.height = height;

		if (alpha) {
			context.globalAlpha = Math.random();
		}
		context.fillStyle = background;

		context.fillRect(0, 0, width, height);

		for (var i = 0; i < Math.random() * 10; i++) {

			context.fillStyle = this.getRandomColor(alpha || undefined);

			var rectWidth = Math.round(Math.random() * width),
				rectHeight = Math.round(Math.random() * height);

			context.fillRect(
				Math.round(Math.random() * (width - rectWidth)),
				Math.round(Math.random() * (height - rectHeight)),
				rectWidth,
				rectHeight
			);

			context.save();

		}

		return canvas.toDataURL('image/png', '');

	},

	__spritemaps: [{
		id: 'debug',
		url: 'res/debug.png',
		width: 192,
		height: 192,
		frameColumns: 6,
		frames: 36,
		fps: 30
	}],


	getRandomSprite: function() {

		var id = Math.random() * (this.__spritemaps.length - 1);
		return this.__spritemaps[id];

	},

	plugins: {

		nodecontent: {

			// Does pretty nothing rather than cleanup
			empty: function(object) {
				object.node.innerText = '';
			},

			text: function(object) {

				var charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.split(''),
					str = '';

				for (var c = 0, l = Math.random() * 20; c < l; c++) {
					str += charset[Math.round(Math.random() * (charset.length - 1))];
				}

				object.node.innerText = str;
				object.node.style.color = this.getRandomColor();
				// object.node.style.backgroundColor = '';

			}


		},

		nodebackground: {

			rgb: function(object) {
				object.node.style.background = this.getRandomColor();
			},

			rgba: function(object) {
				object.node.style.background = 'rgba(' + Math.round(Math.random() * 255) + ',' + Math.round(Math.random() * 255) + ',' + Math.round(Math.random() * 255) + ',' + Math.random() + ')';
			},

			gradient: function(object) {

				var a = z.css.gradient.linear;
				if (a && a.length) {
					object.node.style.background = 'rgba(0,0,0,0)';
					object.node.style[a[0]] = a[1].replace(/%1%/, this.getRandomColor(Math.random())).replace(/%2%/, this.getRandomColor(0.0));
				}

			},

			'gradient-radial': function(object) {

				var a = z.css.gradient.radial;
				if (a && a.length) {
					object.node.style.background = 'rgba(0,0,0,0)';
					object.node.style[a[0]] = a[1].replace(/%1%/, this.getRandomColor(Math.random())).replace(/%2%/, this.getRandomColor(0.0));
				}

			},

			image: function(object) {

				var image = this.getRandomImage(
					object.width,
					object.height,
					this.getRandomColor()
				);

				object.node.style.backgroundImage = 'url(' + image + ')';

			},

			'image-alpha': function(object) {

				var image = this.getRandomImage(
					object.width,
					object.height,
					this.getRandomColor(Math.random()),
					Math.random()
				);

				object.node.style.background = 'rgba(0,0,0,0)';
				object.node.style.backgroundImage = 'url(' + image + ')';

			},

			sprite: function(object) {

				// remove legacy spriteNode
				if (object.spriteNode) {
					object.node.removeChild(object.spriteNode);
					object.spriteNode = undefined;
				}


				// update object properties with sprite information
				object.sprite = this.getRandomSprite();
				object.width = object.sprite.width / object.sprite.frameColumns;
				object.height = object.sprite.height / (object.sprite.frames / object.sprite.frameColumns);

				object.node.style.width = object.width + 'px';
				object.node.style.height = object.height + 'px';


				object.node.style.backgroundImage = 'url(' + object.sprite.url + ')';
				object.node.style.backgroundPosition = '0px 0px';

			},

			'sprite-translate3d': function(object) {

				// update object properties with sprite information
				object.sprite = this.getRandomSprite();
				object.width = object.sprite.width / object.sprite.frameColumns;
				object.height = object.sprite.height / (object.sprite.frames / object.sprite.frameColumns);

				object.node.style.overflow = 'hidden';
				object.node.style.width = object.width + 'px';
				object.node.style.height = object.height + 'px';

				object.spriteNode = document.createElement('div');
				object.node.appendChild(object.spriteNode);

				object.spriteNode.style.width = object.sprite.width + 'px';
				object.spriteNode.style.height = object.sprite.height + 'px';
				object.spriteNode.style.backgroundImage = 'url(' + object.sprite.url + ')';

			}

		}

	}

});
