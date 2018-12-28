
(function(global) {

	global.addEventListener('DOMContentLoaded', _ => {

		const requestFrame = global.requestAnimationFrame || function(cb) { setTimeout(cb, 1000 / 40); };

		const doc    = global.document;
		const avatar = doc.createElement('canvas');
		const figure = doc.querySelector('figure#avatar');
		const buffer = doc.createElement('canvas');
		const vomit  = doc.createElement('canvas');

		const sounds = (function() {

			let opus   = false;
			let ogg    = false;
			let mp3    = false;
			let burp   = null;
			let melody = null;
			let ouch   = null;
			let vomit  = null;


			let audio = 'Audio' in global && typeof Audio !== 'undefined';
			if (audio === true) {

				let check = new Audio();

				if (check.canPlayType('audio/opus')) opus = true;
				if (check.canPlayType('audio/ogg'))  ogg  = true;
				if (check.canPlayType('audio/mpeg')) mp3  = true;

				check = null;

				let ext = 'mp3';

				if (opus === true) {
					ext = 'opus';
				} else if (ogg === true) {
					ext = 'ogg';
				}

				burp   = new Audio('design/avatar/burp.'   + ext);
				melody = new Audio('design/avatar/melody.' + ext);
				ouch   = new Audio('design/avatar/ouch.'   + ext);
				vomit  = new Audio('design/avatar/vomit.'  + ext);

			}

			return {
				burp:   burp,
				melody: melody,
				ouch:   ouch,
				vomit:  vomit
			};

		})();



		/*
		 * CONSTANTS
		 */

		const COLORS = {
			face:  [ 15, 153, 203 ],
			mouth: [  0,   0,   0 ],
			ouch:  [ 203, 15, 153 ],
			vomit: [ 15, 203, 153 ]
		};

		const EYES = [{
			ball: {
				x: 130,
				y: 80,
				r: 40
			},
			pupil: {
				x: 132,
				y: 102,
				r: 9
			}
		}, {
			ball: {
				x: 184,
				y: 81,
				r: 26,
			},
			pupil: {
				x: 178,
				y: 76,
				r: 6
			}
		}];

		const MOUTH = {
			melody: {
				peaks: [ 250, 650, 900, 1190, 1470, 1750, 2500, 2740, 2860, 3000 ],
				open:  {
					bezier: [ 15, 212, 140, 261, 214, 156 ],
					offset: { x: 44, y: 124 }
				},
				shut:  {
					bezier: [ 65, 190, 141, 208, 198, 176 ],
					offset: { x: 41, y: 146 }
				}
			},
			okay: {
				bezier: [ 15, 212, 140, 261, 214, 156 ],
				offset: { x: 44, y: 124 }
			},
			ouch: {
				bezier: [ 65, 190, 141, 208, 198, 176 ],
				offset: { x: 41, y: 146 }
			},
			sick: {
				bezier: [ 65, 190, 141, 208, 198, 176 ],
				offset: { x: 41, y: 146 }
			}
		};

		const VOMIT = new Array(360 / 10).fill(0).map((id, p) => ({
			id:    id,
			x:     0,
			y:     0,
			angle: p * 10,
			blob:  null,
			size:  null,
			life:  null
		}));



		/*
		 * HELPERS
		 */

		const _ease_in  = t => Math.pow(t, 3);
		const _ease_out = t => Math.pow(t - 1, 3) + 1;

		const _draw_face = (ctx, width, height, time) => {

			let t = time.nausea / 100;

			let color1 = COLORS.face;
			let color2 = COLORS.face;

			if (time.feeling === 'sick') {

				color2 = COLORS.vomit;
				t = _ease_out(time.nausea / 100);

			} else if (time.feeling === 'ouch') {

				let dt = time.now - time.beatup;
				if (dt < 500) {
					color2 = COLORS.ouch;
					t = _ease_out(dt / 500);
				} else if (dt < 1000) {
					color2 = COLORS.ouch;
					t = _ease_out(1 - ((dt - 500) / 500));
				} else {
					t = 1;
				}

			} else if (time.feeling === 'vomit') {

				color2 = COLORS.vomit;

				let dt = time.now - time.throwup;
				if (dt > 250) {
					t = 0;
				}

			}


			let color_r = (color1[0] + t * (color2[0] - color1[0]) | 0);
			let color_g = (color1[1] + t * (color2[1] - color1[1]) | 0);
			let color_b = (color1[2] + t * (color2[2] - color1[2]) | 0);
			let radius  = Math.min(width, height) / 2;

			ctx.clearRect(0, 0, width, height);

			ctx.beginPath();
			ctx.arc(width / 2 | 0, height / 2 | 0, radius | 0, 0, Math.PI * 2);
			ctx.fillStyle = 'rgb(' + color_r + ',' + color_g + ',' + color_b + ')';
			ctx.fill();
			ctx.closePath();

		};

		const _draw_eye_ball = (ctx, eye, pos, time) => {

			let dist = Math.sqrt(Math.pow(eye.ball.x - pos.x, 2) + Math.pow(eye.ball.y - pos.y, 2), 2);

			if (time.feeling === 'ouch') {

				ctx.beginPath();
				ctx.ellipse(
					eye.ball.x,
					eye.ball.y,
					eye.ball.r,
					eye.ball.r * 0.75 - eye.ball.r * 0.15 * (1 - (dist / 128)),
					0,
					0,
					Math.PI * 2
				);
				ctx.fillStyle = '#ffffff';
				ctx.fill();
				ctx.closePath();

			} else if (dist < 128) {

				ctx.beginPath();
				ctx.ellipse(
					eye.ball.x,
					eye.ball.y,
					eye.ball.r,
					eye.ball.r - eye.ball.r * 0.15 * (1 - (dist / 128)),
					0,
					0,
					Math.PI * 2
				);
				ctx.fillStyle = '#ffffff';
				ctx.fill();
				ctx.closePath();

			} else {

				ctx.beginPath();
				ctx.arc(
					eye.ball.x,
					eye.ball.y,
					eye.ball.r,
					0,
					Math.PI * 2
				);
				ctx.fillStyle = '#ffffff';
				ctx.fill();
				ctx.closePath();

			}

		};

		const _draw_eye_pupil = (ctx, eye, pos, time) => {

			if (pos.x !== null && pos.y !== null) {

				let delta_x = pos.x - eye.ball.x;
				let delta_y = pos.y - eye.ball.y;
				let radian  = Math.atan2(delta_y, delta_x);
				let radius  = Math.min(eye.ball.r - eye.pupil.r - 2, Math.sqrt(Math.pow(delta_x, 2) + Math.pow(delta_y, 2)));
				let pupil_x = eye.ball.x + Math.cos(radian) * radius;
				let pupil_y = eye.ball.y + Math.sin(radian) * radius;

				eye.pupil.x = pupil_x;
				eye.pupil.y = pupil_y;

			}

			ctx.beginPath();
			ctx.arc(
				eye.pupil.x,
				eye.pupil.y,
				eye.pupil.r,
				0,
				Math.PI * 2
			);
			ctx.fillStyle = '#000000';
			ctx.fill();
			ctx.closePath();

		};

		const _draw_mouth = (ctx, time) => {

			if (
				time.feeling === 'okay'
				|| time.feeling === 'sick'
			) {

				let f = _ease_out(time.nausea / 100);

				let bezier1 = MOUTH.okay.bezier;
				let bezier2 = MOUTH.sick.bezier;
				let offset1 = MOUTH.okay.offset;
				let offset2 = MOUTH.sick.offset;


				ctx.beginPath();
				ctx.moveTo(
					offset1.x + f * (offset2.x - offset1.x),
					offset1.y + f * (offset2.y - offset1.y)
				);
				ctx.fillStyle = '#000000';
				ctx.bezierCurveTo(
					bezier1[0] + f * (bezier2[0] - bezier1[0]),
					bezier1[1] + f * (bezier2[1] - bezier1[1]),
					bezier1[2] + f * (bezier2[2] - bezier1[2]),
					bezier1[3] + f * (bezier2[3] - bezier1[3]),
					bezier1[4] + f * (bezier2[4] - bezier1[4]),
					bezier1[5] + f * (bezier2[5] - bezier1[5])
				);
				ctx.fill();
				ctx.closePath();

			} else if (time.feeling === 'melody') {

				let dt    = Date.now() - time.melody;
				let peaks = MOUTH.melody.peaks;
				let next  = peaks.find(v => v > dt) || 0;
				let last  = peaks[peaks.indexOf(next) - 1] || 0;

				if (next !== 0) {

					let f       = _ease_out((dt - last) / (next - last));
					let bezier1 = MOUTH.melody.shut.bezier;
					let bezier2 = MOUTH.melody.open.bezier;
					let offset1 = MOUTH.melody.shut.offset;
					let offset2 = MOUTH.melody.open.offset;

					ctx.beginPath();
					ctx.moveTo(
						offset1.x + f * (offset2.x - offset1.x),
						offset1.y + f * (offset2.y - offset1.y)
					);
					ctx.fillStyle = '#000000';
					ctx.bezierCurveTo(
						bezier1[0] + f * (bezier2[0] - bezier1[0]),
						bezier1[1] + f * (bezier2[1] - bezier1[1]),
						bezier1[2] + f * (bezier2[2] - bezier1[2]),
						bezier1[3] + f * (bezier2[3] - bezier1[3]),
						bezier1[4] + f * (bezier2[4] - bezier1[4]),
						bezier1[5] + f * (bezier2[5] - bezier1[5])
					);
					ctx.fill();
					ctx.closePath();

				} else {

					let bezier = MOUTH.melody.open.bezier;
					let offset = MOUTH.melody.open.offset;

					ctx.beginPath();
					ctx.moveTo(
						offset.x,
						offset.y
					);
					ctx.fillStyle = '#000000';
					ctx.bezierCurveTo(
						bezier[0],
						bezier[1],
						bezier[2],
						bezier[3],
						bezier[4],
						bezier[5]
					);
					ctx.fill();
					ctx.closePath();

				}

			} else if (time.feeling === 'ouch') {

				let bezier = MOUTH.ouch.bezier;
				let offset = MOUTH.ouch.offset;


				ctx.beginPath();
				ctx.moveTo(
					offset.x,
					offset.y
				);
				ctx.fillStyle = '#000000';
				ctx.bezierCurveTo(
					bezier[0],
					bezier[1],
					bezier[2],
					bezier[3],
					bezier[4],
					bezier[5]
				);
				ctx.fill();
				ctx.closePath();

			} else if (time.feeling === 'vomit') {

				let dt = time.now - time.throwup;
				if (dt < 250) {

					let f       = _ease_out(dt / 250);
					let color_r = COLORS.mouth[0] + f * (COLORS.vomit[0] - COLORS.mouth[0]);
					let color_g = COLORS.mouth[1] + f * (COLORS.vomit[1] - COLORS.mouth[1]);
					let color_b = COLORS.mouth[2] + f * (COLORS.vomit[2] - COLORS.mouth[2]);
					let bezier  = MOUTH.sick.bezier;
					let offset  = MOUTH.sick.offset;

					ctx.beginPath();
					ctx.moveTo(offset.x, offset.y);
					ctx.fillStyle = 'rgb(' + color_r + ',' + color_g + ',' + color_b + ')';
					ctx.bezierCurveTo(
						bezier[0],
						bezier[1],
						bezier[2],
						bezier[3],
						bezier[4],
						bezier[5]
					);
					ctx.fill();
					ctx.closePath();

				} else if (dt > 250) {

					let t = (dt - 250) / 1000;
					if (t < 1) {

						let f       = _ease_out(t);
						let color_r = COLORS.vomit[0] + f * (COLORS.mouth[0] - COLORS.vomit[0]);
						let color_g = COLORS.vomit[1] + f * (COLORS.mouth[1] - COLORS.vomit[1]);
						let color_b = COLORS.vomit[2] + f * (COLORS.mouth[2] - COLORS.vomit[2]);
						let bezier1 = MOUTH.sick.bezier;
						let bezier2 = MOUTH.okay.bezier;
						let offset1 = MOUTH.sick.offset;
						let offset2 = MOUTH.okay.offset;


						ctx.beginPath();
						ctx.moveTo(
							offset1.x + f * (offset2.x - offset1.x),
							offset1.y + f * (offset2.y - offset1.y)
						);
						ctx.fillStyle = 'rgb(' + color_r + ',' + color_g + ',' + color_b + ')';
						ctx.bezierCurveTo(
							bezier1[0] + f * (bezier2[0] - bezier1[0]),
							bezier1[1] + f * (bezier2[1] - bezier1[1]),
							bezier1[2] + f * (bezier2[2] - bezier1[2]),
							bezier1[3] + f * (bezier2[3] - bezier1[3]),
							bezier1[4] + f * (bezier2[4] - bezier1[4]),
							bezier1[5] + f * (bezier2[5] - bezier1[5])
						);
						ctx.fill();
						ctx.closePath();

					} else {

						let bezier = MOUTH.okay.bezier;
						let offset = MOUTH.okay.offset;

						ctx.beginPath();
						ctx.moveTo(offset.x, offset.y);
						ctx.fillStyle = '#000000';
						ctx.bezierCurveTo(
							bezier[0],
							bezier[1],
							bezier[2],
							bezier[3],
							bezier[4],
							bezier[5]
						);
						ctx.fill();
						ctx.closePath();

					}

				}

			} else {

				let bezier = MOUTH.okay.bezier;
				let offset = MOUTH.okay.offset;

				ctx.beginPath();
				ctx.moveTo(
					offset.x,
					offset.y
				);
				ctx.fillStyle = '#000000';
				ctx.bezierCurveTo(
					bezier[0],
					bezier[1],
					bezier[2],
					bezier[3],
					bezier[4],
					bezier[5]
				);
				ctx.fill();
				ctx.closePath();

			}

		};

		const _draw_vomit = (ctx, pos, offset, time) => {

			if (time.vomited === null) {

				if (pos.x === null) pos.x = Math.random() * vomit.width;
				if (pos.y === null) pos.y = Math.random() * vomit.height;

				for (let p = 0, pl = VOMIT.length; p < pl; p++) {

					let particle = VOMIT[p];

					particle.x    = offset.x + pos.x;
					particle.y    = offset.y + pos.y;
					particle.size = 16 + Math.random() * 16;
					particle.blob = particle.size;
					particle.life = 250 + Math.random() * 250;

				};

				time.vomited = time.now;

			}


			let dt = time.now - time.throwup;
			let t  = dt / (time.recover - time.throwup);

			if (dt < 100) {

				// Wait for actual throwup

			} else if (dt > 250 && dt < 750) {

				let t = (dt - 250) / 500;

				ctx.fillStyle = 'rgba(' + COLORS.vomit.join(',') + ', 0.5)';

				for (let p = 0, pl = VOMIT.length; p < pl; p++) {

					let particle = VOMIT[p];
					if (particle.life > 0) {

						let f = _ease_out(t);

						particle.x    += Math.cos(particle.angle) * (1 - f) * 32 + Math.random() * 8 - Math.random() * 8;
						particle.y    += Math.sin(particle.angle) * (1 - f) * 32 + Math.random() * 8 - Math.random() * 8;
						particle.life -= time.delta;
						particle.size *= (1 - f);

						if (particle.size <= 0) {
							particle.life = 0;
						}


						ctx.beginPath();
						ctx.arc(
							particle.x,
							particle.y,
							particle.size,
							0,
							Math.PI * 2
						);
						ctx.fill();
						ctx.closePath();

					}

				};

			} else if (dt > 750 && dt < 1250) {

				let t = (dt - 750) / 500;

				if (buffer._full !== true) {
					buffer.getContext('2d').drawImage(vomit, 0, 0);
					buffer._full = true;
				}


				ctx.clearRect(0, 0, vomit.width, vomit.height);
				ctx.globalAlpha = 1 - t;
				ctx.drawImage(buffer, 0, 0);
				ctx.globalAlpha = 1;

			}

		};

		const _render = (ctx, pos, time) => {

			_draw_face(ctx, avatar.width, avatar.height, time);
			_draw_eye_ball(ctx,  EYES[0], pos, time);
			_draw_eye_ball(ctx,  EYES[1], pos, time);
			_draw_eye_pupil(ctx, EYES[0], pos, time);
			_draw_eye_pupil(ctx, EYES[1], pos, time);
			_draw_mouth(ctx, time);


			if (time.feeling === 'vomit') {

				_draw_vomit(vomit.getContext('2d'), {
					x: pos.x - global.scrollX,
					y: pos.y - global.scrollY
				}, offset, time);

			} else {

				if (buffer._full === true) {

					let ctx_buffer = buffer.getContext('2d');
					let ctx_vomit  = vomit.getContext('2d');

					ctx_buffer.clearRect(0, 0, buffer.width, buffer.height);
					ctx_vomit.clearRect(0, 0, vomit.width, vomit.height);

					buffer._full = false;

				}

			}


			requestFrame(_ => {
				_render(ctx, pos, time);
			});

		};

		const _update_offset = (offset, x, y, scroll) => {

			scroll = typeof scroll === 'number' ? scroll : 0;


			offset.x = x + 16;
			offset.y = y + 16;

			if (scroll > 0) {
				offset.y += scroll;
			}

		};

		const _update_position = (pos, time) => {

			if (time._event === null) {
				time._event = Date.now();
			}

			let delta = (Date.now() - time._event) / 1000;
			let dist  = Math.sqrt(Math.pow(pos.dx, 2) + Math.pow(pos.dy, 2), 2);

			if (delta * dist > 1) {

				if (timeline.feeling !== 'ouch') {
					time.feeling = 'sick';
					time.shaked  = Date.now();
				}

			}

			time._event = Date.now();

		};

		const _update_rotation = (rot, time) => {

			if (time._event === null) {
				time._event = Date.now();
			}

			let x = Math.abs(rot.x);
			let y = Math.abs(rot.y);
			let z = Math.abs(rot.z);

			if (x > 10 || y > 10 || z > 10) {

				if (timeline.feeling !== 'ouch') {
					time.feeling = 'sick';
					time.shaked  = Date.now();
				}

			}

			time._event = Date.now();

		};

		const _update = (time) => {

			time.delta = Date.now() - time.now;
			time.now   = Date.now();


			if (time.feeling === 'okay') {

				if (time.nausea > 1) {
					time.nausea -= 1;
				}

			} else if (time.feeling === 'sick') {

				if (time.shaked !== null) {

					if (Date.now() > time.shaked + 100) {

						if (sounds.burp !== null && time.nausea > 67) {
							try {
								let p = sounds.burp.play();
								p.catch((err) => {});
							} catch (err) {
							}
						}

						time.feeling = 'okay';
						time.shaked  = null;

					}

				}

				if (time.nausea < 100) {
					time.nausea += 1;
				}

			}

			if (time.nausea >= 100) {
				time.nausea  = 100;
				time.feeling = 'vomit';
			}

			if (time.feeling === 'vomit') {

				if (time.throwup === null) {

					if (sounds.vomit !== null) {
						try {
							let p = sounds.vomit.play();
							p.catch((err) => {});
						} catch (err) {
						}
					}

					time.throwup = Date.now();
					time.recover = Date.now() + 250 + 500 + 500;

				} else if (Date.now() > time.recover) {

					time.feeling = 'okay';
					time.nausea  = 0;
					time.recover = Infinity;
					time.throwup = null;
					time.vomited = null;

				}

			}

		};



		/*
		 * IMPLEMENTATION
		 */

		let offset = {
			x: 0,
			y: 0
		};

		let position = {
			x:  null,
			y:  null,
			dx: 0,
			dy: 0
		};

		let timeline = {
			_event:  null,
			beatup:  null,
			feeling: 'okay',
			nausea:  0,
			melody:  null,
			now:     Date.now(),
			recover: Infinity,
			shaked:  null,
			throwup: null,
			vomited: null
		};



		if (figure !== null) {

			figure.style.position = 'relative';


			let image = figure.querySelector('img');
			if (image !== null && avatar !== null) {

				let w = Number.parseInt(image.getAttribute('width'),  10);
				let h = Number.parseInt(image.getAttribute('height'), 10);

				avatar.width        = w;
				avatar.height       = h;
				avatar.style.width  = w + 'px';
				avatar.style.height = h + 'px';

				avatar.addEventListener('click', event => {

					if (timeline.feeling !== 'ouch') {

						if (sounds.ouch !== null) {
							timeline.feeling = 'ouch';
							timeline.beatup  = Date.now();

							try {
								let p = sounds.ouch.play();
								p.catch((err) => {});
							} catch (err) {
							}

						}

						setTimeout(_ => {
							timeline.feeling = 'okay';
							timeline.beatup  = null;
						}, 1000);

					}

				}, true);


				let rect = image.getBoundingClientRect();
				if (rect !== null) {
					_update_offset(offset, rect.left, rect.top, global.scrollY || 0);
				}


				let context = avatar.getContext('2d');
				if (context !== null) {

					requestFrame(_ => _render(context, position, timeline));
					setInterval(_ => _update(timeline), 1000 / 60);

					setInterval(_ => {

						if (sounds.melody !== null) {

							if (timeline._event !== null && timeline.feeling === 'okay') {

								if (Date.now() > timeline._event + 60000 && Math.random() > 0.75) {

									timeline._event  = null;
									timeline.feeling = 'melody';
									timeline.melody  = Date.now();

									try {
										let p = sounds.melody.play();
										p.catch((err) => {});
									} catch (err) {
									}

									setTimeout(_ => {
										timeline._event  = Date.now();
										timeline.feeling = 'okay';
										timeline.melody  = null;
									}, 3500);

								}

							}

						}

					}, 30000);

				}


				figure.appendChild(avatar);

			}


			if (buffer !== null) {
				buffer.width  = global.innerWidth;
				buffer.height = global.innerHeight;
			}

			if (vomit !== null) {

				vomit.width                   = global.innerWidth;
				vomit.height                  = global.innerHeight;
				vomit.style['display']        = 'block';
				vomit.style['position']       = 'fixed';
				vomit.style['width']          = global.innerWidth + 'px';
				vomit.style['height']         = global.innerHeight + 'px';
				vomit.style['zIndex']         = 100;
				vomit.style['top']            = '0px';
				vomit.style['right']          = '0px';
				vomit.style['bottom']         = '0px';
				vomit.style['left']           = '0px';
				vomit.style['pointer-events'] = 'none';

				let body = doc.querySelector('body');
				if (body !== null) {
					body.appendChild(vomit);
				}

			}



			/*
			 * EVENTS
			 */

			doc.addEventListener('mousemove', event => {

				let px = event.pageX - offset.x;
				let py = event.pageY - offset.y;

				if (position.x !== null) position.dx = px - position.x;
				if (position.y !== null) position.dy = py - position.y;

				position.x = px;
				position.y = py;

				_update_position(position, timeline);

			}, true);

			doc.addEventListener('touchmove', event => {

				let px = event.touches[0].pageX - offset.x;
				let py = event.touches[0].pageY - offset.y;

				if (position.x !== null) position.dx = px - position.x;
				if (position.y !== null) position.dy = py - position.y;

				position.x = px;
				position.y = py;

				_update_position(position, timeline);

			}, true);

			if ('ondevicemotion' in global) {

				global.addEventListener('devicemotion', event => {

					let rotation_rate = event.rotationRate || null;
					if (rotation_rate !== null) {

						let rotation = {
							x: event.rotationRate.beta  || 0,
							y: event.rotationRate.gamma || 0,
							z: event.rotationRate.alpha || 0
						};

						_update_rotation(rotation, timeline);

					}

				}, true);

			}

			if ('onresize' in global) {

				global.addEventListener('resize', event => {

					let rect = image.getBoundingClientRect();
					if (rect !== null) {
						_update_offset(offset, rect.left, rect.top, global.scrollY || 0);
					}


					if (vomit !== null) {

						vomit.width           = global.innerWidth;
						vomit.height          = global.innerHeight;
						vomit.style['width']  = global.innerWidth  + 'px';
						vomit.style['height'] = global.innerHeight + 'px';

					}

				}, true);

			}

		}

	}, true);

})(typeof window !== 'undefined' ? window : this);

