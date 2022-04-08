
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const requestFrame = global.requestAnimationFrame || function(cb) { setTimeout(cb, 1000 / 40); };

		const doc     = global.document;
		const body    = doc.body;
		const avatar  = doc.querySelector('#about figure img');
		const consent = doc.createElement('div');

		consent.innerHTML = [
			'<h3>We value your Privacy</h3>',
			'<p>By clicking "Consent" you agree that the whole Internet and our Partners have the right to store and/or access information on your device through the use of cookies and similar technologies and process your personal data, to display personalized ads and content, for ad and content measurement, audience insights and product development. Haha, just kidding. Do you consent to sharing Cookies?</p>',
			'<div>',
			'<button onclick="alert(\'You are tracked! Are you happy nao?\')">Consent</button>',
			'<button onclick="GAME.start()">Do Not Consent</button>',
			'</div>'
		].join('');

		consent.setAttribute('id', 'consent');
		body.appendChild(consent);



		const canvas   = doc.querySelector('body > canvas');
		const GFX      = canvas.getContext('2d');
		const SFX      = new AudioContext();
		const ANALYSER = SFX.createAnalyser();


		const renderBorder = (border) => {

			let rect = avatar.getBoundingClientRect();

			GFX.globalCompositeOperation = 'source-over';

			GFX.beginPath();
			GFX.arc(rect.left + 128 + 16, rect.top + 128 + 16, 128 + border, 0, 2 * Math.PI, false);
			GFX.arc(rect.left + 128 + 16, rect.top + 128 + 16, 128,          0, 2 * Math.PI, true);
			GFX.fillStyle = '#252530';
			GFX.fill();

			GFX.globalCompositeOperation = 'destination-out';
			GFX.beginPath();
			GFX.arc(rect.left + 128 + 16, rect.top + 128 + 16, 128, 0, 2 * Math.PI, false);
			GFX.fill();

			GFX.globalCompositeOperation = 'source-over';

		};

		const renderCannon = (cursor, image) => {

			let dx    = (canvas.width / 2)   - cursor.x;
			let dy    = (canvas.height - 64) - cursor.y;
			let theta = Math.atan2(dy, dx);


			GFX.globalCompositeOperation = 'source-over';

			GFX.save();
			GFX.translate(canvas.width / 2, canvas.height - 64);
			GFX.rotate(-1 * Math.PI / 2);
			GFX.rotate(theta);
			GFX.drawImage(image, -64/2, -96/2);
			GFX.restore();


			if (cursor.lazer > 0) {

				GFX.lineWidth   = cursor.lazer;
				GFX.strokeStyle = '#0f99cb';

				GFX.beginPath();
				GFX.moveTo(canvas.width / 2, canvas.height - 64);
				GFX.lineTo(cursor.x, cursor.y);
				GFX.stroke();

			}

		};

		const renderCookies = (cookies, border, image) => {

			let radius = 16 + ((border - 16) / 16 * 8);

			GFX.globalCompositeOperation = 'source-over';

			for (let c = 0, cl = cookies.length; c < cl; c++) {

				let cookie = cookies[c];

				GFX.drawImage(
					image,
					0,
					0,
					32,
					32,
					cookie.x - radius,
					cookie.y - radius,
					radius * 2,
					radius * 2
				);

			}

		};

		const renderEqualizer = (equalizer) => {

			let x = 0;
			let w = canvas.width / equalizer.length;

			GFX.globalCompositeOperation = 'source-over';

			GFX.beginPath();
			GFX.lineWidth   = 2;
			GFX.strokeStyle = '#252530';

			for (let e = 0, el = equalizer.length; e < el; e++) {

				let value = equalizer[e] / 128.0;
				let y     = (value * 512 / 2) + 48;

				if (e === 0) {
					GFX.moveTo(x, y);
				} else {
					GFX.lineTo(x, y);
				}

				x += w;

			}

			GFX.lineTo(canvas.width, 0);
			GFX.stroke();

		};

		const renderHealth = (health) => {

			GFX.globalCompositeOperation = 'source-over';

			if (health[0] === health[1]) {

				GFX.fillStyle = '#0f99cb';
				GFX.fillRect(0, canvas.height - 16, canvas.width * (health[0] / 100), 16);

			} else if (health[0] > health[1]) {

				GFX.fillStyle = '#92dcf7';
				GFX.fillRect(0, canvas.height - 16, canvas.width * (health[0] / 100), 16);

				GFX.fillStyle = '#0f99cb';
				GFX.fillRect(0, canvas.height - 16, canvas.width * (health[1] / 100), 16);

			} else if (health[0] < health[1]) {

				GFX.fillStyle = '#f792dc';
				GFX.fillRect(0, canvas.height - 16, canvas.width * (health[1] / 100), 16);

				GFX.fillStyle = '#cb0f99';
				GFX.fillRect(0, canvas.height - 16, canvas.width * (health[0] / 100), 16);

			}

		};

		const loadImage = (url) => new Promise((resolve) => {

			let image = new Image();

			image.src = url;

			image.onload = () => {
				resolve(image);
			};

		});

		const loadAudio = function(url) {

			return new Promise((resolve) => {
				global.fetch(url).then((response) => {
					return response.arrayBuffer();
				}).then((buffer) => {
					SFX.decodeAudioData(buffer, (decoded) => {
						resolve(decoded);
					});
				});
			});

		};

		const playAudio = function(buffer, loop) {

			let node = SFX.createBufferSource();

			node.buffer = buffer;
			node.connect(SFX.destination);

			if (loop === true) {
				node.loop = true;
			}

			node.start(0);

			return node;

		};



		global.GAME = (function() {

			const CACHE = {
				audio: {
					booom: null,
					lazer: null,
					music: null
				},
				image: {
					cannon: null,
					cookie: null
				}
			};

			const STATE = {
				border:    32,
				cookies:   [],
				cursor:    {
					x:     0,
					y:     0,
					lazer: 0
				},
				equalizer: new Uint8Array(2048),
				health:    [ 100, 100 ],
				intervals: [],
				music:     null,
				timer:     null
			};



			const donothing = function(event) {

				if (typeof event.preventDefault === 'function') {
					event.preventDefault();
				}

				return false;

			};

			const focus = function(event) {

				let cursor = STATE['cursor'];

				if (typeof event.touches !== 'undefined') {
					cursor.x = event.touches[0].pageX;
					cursor.y = event.touches[0].pageY;
				} else if (typeof event.x === 'number' && typeof event.y === 'number') {
					cursor.x = event.x;
					cursor.y = event.y;
				}

			};

			const pewpew = function(event) {

				let cookies = STATE['cookies'];
				let cursor  = STATE['cursor'];
				let health  = STATE['health'];

				if (typeof event.touches !== 'undefined') {
					cursor.x = event.touches[0].pageX;
					cursor.y = event.touches[0].pageY;
				} else if (typeof event.x === 'number' && typeof event.y === 'number') {
					cursor.x = event.x;
					cursor.y = event.y;
				}

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

					if (health[0] < 100) {
						health[0] = health[0] + 1;
					}

					if (health[0] > 100) {
						health[0] = 100;
					}

					playAudio(CACHE['audio']['lazer']);

					setTimeout(() => {
						playAudio(CACHE['audio']['booom']);
					}, 100);

				} else {

					playAudio(CACHE['audio']['lazer']);

				}


				return false;

			};



			ANALYSER.fftSize = 2048;

			loadAudio('/design/consent/music.mp3').then((data) => {
				CACHE['audio']['music'] = data;
			});

			loadAudio('/design/consent/lazer.mp3').then((data) => {
				CACHE['audio']['lazer'] = data;
			});

			loadAudio('/design/consent/booom.mp3').then((data) => {
				CACHE['audio']['booom'] = data;
			});

			loadImage('/design/consent/cannon.png').then((data) => {
				CACHE['image']['cannon'] = data;
			});

			loadImage('/design/consent/cookie.png').then((data) => {
				CACHE['image']['cookie'] = data;
			});


			const render = function() {

				GFX.globalCompositeOperation = 'source-over';
				GFX.clearRect(0, 0, canvas.width, canvas.height);

				renderEqualizer(STATE['equalizer']);
				renderBorder(STATE['border']);
				renderCookies(STATE['cookies'], STATE['border'], CACHE['image']['cookie']);
				renderCannon(STATE['cursor'], CACHE['image']['cannon']);
				renderHealth(STATE['health']);

				if (STATE['intervals'].length > 0) {
					requestFrame(render);
				}

			};

			const update = function(delta) {

				ANALYSER.getByteTimeDomainData(STATE['equalizer']);


				let cookies = STATE['cookies'];
				let cursor  = STATE['cursor'];
				let health  = STATE['health'];

				// TODO: Update new health[0]
				// TODO: Update old health[1]


				health[1] = health[0];


				for (let c = 0, cl = cookies.length; c < cl; c++) {

					let cookie = cookies[c];

					cookie.y += cookie.speed * (delta / 1000);

					if (cookie.y > canvas.height) {

						health[0] = health[0] - cookie.lifetime;

						cookie.lifetime = 0;
						cookies.splice(c, 1);
						cl--;
						c--;

					}

				}

				if (cursor.lazer > 0) {
					cursor.lazer--;
				}

				if (health[0] < health[1]) {
					playAudio(CACHE['audio']['booom']);
				}

				if (STATE['border'] > 16) {
					STATE['border'] -= 2;
				}

				if (health[0] <= 0) {
					global.GAME.stop();
				}

			};



			const start = function() {

				global.scrollTo({
					top:      0,
					left:     0,
					behavior: 'smooth'
				});


				STATE['health'] = [ 100, 100 ];
				STATE['music']  = playAudio(CACHE['audio']['music'], true);
				STATE['music'].connect(ANALYSER);


				setTimeout(() => {

					STATE['intervals'].push(setInterval(() => {

						STATE['cookies'].push({
							x:        48 + (Math.random() * canvas.width - 64 - 32),
							y:        0,
							speed:    32 + (Math.random() * 32),
							lifetime: (Math.random() * 2) + 2
						});

						STATE['border'] = 32;

					}, 1000 * 60 / 123));

				}, 220);


				let timer = Date.now();

				STATE['intervals'].push(setInterval(() => {

					update(Date.now() - timer);
					timer = Date.now();

				}, 1000 / 40));


				canvas.addEventListener('mousedown',  pewpew, false);
				canvas.addEventListener('mousemove',  focus,  false);

				canvas.addEventListener('touchstart', pewpew, false);
				canvas.addEventListener('touchmove',  focus,  false);

				canvas.addEventListener('dragstart',  donothing, false);
				canvas.addEventListener('drop',       donothing, false);

				canvas.style.pointerEvents = 'auto';
				body.className             = 'game';


				requestFrame(render);

			};

			const stop = function() {

				STATE['cursor'].lazer = 0;
				STATE['health'] = [ 0, 0 ];

				if (STATE['music'] !== null) {
					STATE['music'].stop();
					STATE['music'] = null;
				}

				if (STATE['intervals'].length > 0) {

					for (let i = 0, il = STATE['intervals'].length; i < il; i++) {

						clearInterval(STATE['intervals'][i]);

						STATE['intervals'].splice(i, 1);
						il--;
						i--;

					}

				}

				if (STATE['cookies'].length > 0) {
					STATE['cookies'].splice(0, STATE['cookies'].length);
				}


				canvas.removeEventListener('mousedown',  pewpew);
				canvas.removeEventListener('mousemove',  focus);

				canvas.removeEventListener('touchstart', pewpew);
				canvas.removeEventListener('touchmove',  focus);

				canvas.removeEventListener('dragstart', donothing);
				canvas.removeEventListener('drop',      donothing);

				canvas.style.pointerEvents = 'none';
				body.className = '';


				setTimeout(() => {
					GFX.globalCompositeOperation = 'source-over';
					GFX.clearRect(0, 0, canvas.width, canvas.height);
				}, 16);


				let button = consent.querySelector('button');
				if (button !== null) {
					button.onclick = () => {
						consent.parentNode.removeChild(consent);
					};
				}

			};


			return {
				start: start,
				stop:  stop
			};

		})();

	}, true);

})(typeof window !== 'undefined' ? window : this);

