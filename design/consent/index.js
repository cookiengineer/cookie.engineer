
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const requestFrame = global.requestAnimationFrame || function(cb) { setTimeout(cb, 1000 / 40); };

		const doc     = global.document;
		const body    = doc.body;
		const avatar  = doc.querySelector('#about figure img');
		const consent = doc.createElement('div');

		consent.innerHTML = [
			'<h3>We value your Privacy</h3>',
			'<p>Haha, just kidding. Do you consent to sharing Cookies?</p>',
			'<div>',
			'<button onclick="alert(\'Boom! You\'re tracked. Are you happy nao?\')">Consent</button>',
			'<button onclick="startGame()">Do Not Consent</button>',
			'</div>'
		].join('');

		consent.setAttribute('id', 'consent');
		body.appendChild(consent);


		const audiocontext  = new AudioContext();
		const analyser      = audiocontext.createAnalyser();
		const canvas        = doc.querySelector('body > canvas');
		const canvascontext = canvas.getContext('2d');
		const cookieimage   = doc.createElement('img');
		const cannonimage   = doc.createElement('img');

		let booom = null;
		let lazer = null;
		let music = null;

		global.fetch('/design/consent/music.mp3').then((response) => {
			return response.arrayBuffer();
		}).then((buffer) => {
			audiocontext.decodeAudioData(buffer, (decoded) => music = decoded);
		});

		global.fetch('/design/consent/lazer.mp3').then((response) => {
			return response.arrayBuffer();
		}).then((buffer) => {
			audiocontext.decodeAudioData(buffer, (decoded) => lazer = decoded);
		});

		global.fetch('/design/consent/booom.mp3').then((response) => {
			return response.arrayBuffer();
		}).then((buffer) => {
			audiocontext.decodeAudioData(buffer, (decoded) => booom = decoded);
		});

		cookieimage.width  = 32;
		cookieimage.height = 32;
		cookieimage.setAttribute('src', '/design/consent/cookie.png');

		cannonimage.width  = 64;
		cannonimage.height = 96;
		cannonimage.setAttribute('src', '/design/consent/cannon.png');


		const play = function(buffer, loop) {

			let node = audiocontext.createBufferSource();

			node.buffer = buffer;
			node.connect(audiocontext.destination);

			if (loop === true) {
				node.loop = true;
			}

			node.start(0);

			return node;

		};


		let   background = null;
		let   border     = 16;
		let   health     = 100;
		let   interval   = null;
		let   timer      = null;
		const buffer     = new Uint8Array(2048);
		const cookies    = [];
		const cursor     = {
			x:     0,
			y:     0,
			lazer: 0
		};

		const focus = function(event) {
			cursor.x     = event.x;
			cursor.y     = event.y;
		};

		const pewpew = function(event) {

			cursor.x     = event.x;
			cursor.y     = event.y;
			cursor.lazer = 10;

			let got_cookie = false;

			for (let c = 0, cl = cookies.length; c < cl; c++) {

				let cookie = cookies[c];
				if (
					cursor.x > cookie.x - 16
					&& cursor.x < cookie.x + 16
					&& cursor.y > cookie.y - 16
					&& cursor.y < cookie.y + 16
				) {
					cookie.lifetime -= 1;
				}

				if (cookie.lifetime < 1) {

					cookie.lifetime = 0;
					got_cookie = true;

					cookies.splice(c, 1);
					cl--;
					c--;

				}

			}

			if (got_cookie === true) {

				if (health < 100) {
					health += 1;
				}

				play(lazer);

				setTimeout(() => {
					play(booom);
				}, 100);

			} else {
				play(lazer);
			}

			return false;

		};


		const spawn = function() {

			border = 32;

			let cookie = {
				x:        32 + (Math.random() * canvas.width - 64),
				y:        0,
				speed:    32 + (Math.random() * 32),
				lifetime: (Math.random() * 2) + 2
			};

			cookies.push(cookie);

		};

		const render = function() {

			analyser.getByteTimeDomainData(buffer);

			canvascontext.globalCompositeOperation = 'source-over';
			canvascontext.clearRect(0, 0, canvas.width, canvas.height);
			canvascontext.lineWidth   = 2;
			canvascontext.strokeStyle = '#252530';

			canvascontext.beginPath();

			let delta = (Date.now() - timer) / 1000;
			let rect  = avatar.getBoundingClientRect();
			let x     = 0;
			let w     = canvas.width / buffer.length;

			for (let b = 0, bl = buffer.length; b < bl; b++) {

				let value = buffer[b] / 128.0;
				let y     = (value * 512 / 2) + 48;

				if (b === 0) {
					canvascontext.moveTo(x, y);
				} else {
					canvascontext.lineTo(x, y);
				}

				x += w;

			}

			canvascontext.lineTo(canvas.width, 0);
			canvascontext.stroke();

			canvascontext.beginPath();
			canvascontext.arc(rect.left + 128 + 16, rect.top + 128 + 16, 128 + border, 0, 2 * Math.PI, false);
			canvascontext.arc(rect.left + 128 + 16, rect.top + 128 + 16, 128, 0, 2 * Math.PI, true);
			canvascontext.fillStyle = '#252530';
			canvascontext.fill();

			canvascontext.globalCompositeOperation = 'destination-out';
			canvascontext.beginPath();
			canvascontext.arc(rect.left + 128 + 16, rect.top + 128 + 16, 128, 0, 2 * Math.PI, false);
			canvascontext.fill();


			if (border > 16) {
				border -= 2;
			}


			canvascontext.globalCompositeOperation = 'source-over';

			let got_damage = false;

			for (let c = 0, cl = cookies.length; c < cl; c++) {

				let cookie = cookies[c];

				cookie.y += cookie.speed * delta;
				canvascontext.drawImage(cookieimage, cookie.x - 16, cookie.y - 16);

				if (cookie.y > canvas.height) {

					got_damage = true;
					health -= cookie.lifetime;
					cookie.lifetime = 0;
					cookies.splice(c, 1);
					cl--;
					c--;

				}

			}


			let dx    = (canvas.width / 2)   - cursor.x;
			let dy    = (canvas.height - 64) - cursor.y;
			let theta = Math.atan2(dy, dx);

			canvascontext.save();
			canvascontext.translate(canvas.width / 2, canvas.height - 64);
			canvascontext.rotate(-1 * Math.PI / 2);
			canvascontext.rotate(theta);
			canvascontext.drawImage(cannonimage, -64/2, -96/2);
			canvascontext.restore();


			if (cursor.lazer > 0) {

				cursor.lazer--;

				canvascontext.lineWidth   = cursor.lazer;
				canvascontext.strokeStyle = '#0f99cb';

				canvascontext.beginPath();
				canvascontext.moveTo(canvas.width / 2, canvas.height - 64);
				canvascontext.lineTo(cursor.x, cursor.y);
				canvascontext.stroke();

			}

			timer = Date.now();

			if (health > 0) {

				canvascontext.fillStyle = '#0f99cb';
				canvascontext.fillRect(0, canvas.height - 16, canvas.width * (health / 100), 16);

			} else {

				global.stopGame();

			}

			if (got_damage === true) {
				play(booom);
			}

			if (body.className === 'game') {
				requestFrame(render);
			}


		};



		global.stopGame = function() {

			health = 0;

			body.className = '';
			canvas.style.pointerEvents = 'none';

			canvascontext.clearRect(0, 0, canvas.width, canvas.height);

			if (background !== null) {
				background.stop();
				background = null;
			}

			if (interval !== null) {
				clearInterval(interval);
				interval = null;
			}

			cookies.splice(0, cookies.length);
			cursor.lazer = 0;

			let button = consent.querySelector('button');
			if (button !== null) {
				button.onclick = () => {
					consent.parentNode.removeChild(consent);
				};
			}

		};

		global.startGame = function() {

			health = 100;

			body.className             = 'game';
			canvas.style.pointerEvents = 'auto';

			global.scrollTo({
				top:      0,
				left:     0,
				behavior: 'smooth'
			});


			analyser.fftSize = 2048;

			background = play(music, true);
			background.connect(analyser);

			// XXX: beatline is a little messed up, but got too lazy to track again
			setTimeout(() => {
				interval = setInterval(spawn, 1000 * 60 / 123);
			}, 220);


			canvas.addEventListener('click',      pewpew,      false);
			canvas.addEventListener('dragstart',  () => false, false);
			canvas.addEventListener('drop',       () => false, false);
			canvas.addEventListener('mousemove',  focus,       false);
			canvas.addEventListener('touchstart', pewpew,      false);


			requestFrame(render);

		};

	}, true);

})(typeof window !== 'undefined' ? window : this);

