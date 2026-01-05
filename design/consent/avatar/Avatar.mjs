
import { DrawEyeBall         } from "./draw/DrawEyeBall.mjs";
import { DrawEyePupil        } from "./draw/DrawEyePupil.mjs";
import { DrawFace            } from "./draw/DrawFace.mjs";
import { ClearVomit          } from "./draw/ClearVomit.mjs";
import { DrawVomit           } from "./draw/DrawVomit.mjs";
import { DrawMouthExpression } from "./draw/DrawMouthExpression.mjs";
import { DrawMouthPhoneme    } from "./draw/DrawMouthPhoneme.mjs";
import { Phonemes            } from "./mouth/Phonemes.mjs";
import { PlaySound           } from "../common/sound/PlaySound.mjs";
import { GetSpeech           } from "../common/speech/GetSpeech.mjs";
import { PlaySpeech          } from "../common/speech/PlaySpeech.mjs";

export const Avatar = function(figure, width, height) {

	figure = typeof figure === "object" ? figure : document.createElement("figure");
	width  = typeof width === "number"  ? width  : 256;
	height = typeof height === "number" ? height : 256;

	this.debug   = false;
	this.figure  = figure;
	this.canvas  = document.createElement("canvas");
	this.context = this.canvas.getContext("2d");
	this.width   = width;
	this.height  = height;

	this.focus = {
		"x":  null,
		"y":  null,
		"dx": 0,
		"dy": 0
	};

	this.progress = {
		"angry": 0,
		"level": 0,
	};

	this.feeling  = "okay";
	this.speaking = {
		"start":   null,
		"index":   0,
		"phoneme": "",
		"speech":  null
	};
	this.running = false;
	this.statemap = {
		"okay": {
		},
		"angry": {
			"start": null,
			"end":   null
		},
		"sick": {
			"nausea": 0,
			"start":  null,
			"end":    null
		},
		"vomit": {
			"start": null,
			"end":   null
		}
	};

	this.__listeners = {
		pointerdown: null,
		pointermove: null
	};

	// Integration API
	this.IsGameRunning = () => {};
	this.OnGameStart   = () => {};

};

Avatar.prototype = {

	Contort: function(phoneme) {

		typeof phoneme === "string" ? phoneme : "";

		let check = Phonemes[phoneme] || null;
		if (check !== null && phoneme !== "") {

			this.speaking["start"]   = Date.now();
			this.speaking["index"]   = 0;
			this.speaking["phoneme"] = phoneme;
			this.speaking["speech"]  = null;

		} else {

			this.speaking["start"]   = null;
			this.speaking["index"]   = 0;
			this.speaking["phoneme"] = "";
			this.speaking["speech"]  = null;

		}

	},

	Destroy: function() {

		if (this.canvas.parentNode !== null) {

			document.body.removeEventListener("pointermove", this.__listeners.pointermove);
			this.canvas.removeEventListener("pointerdown", this.__listeners.pointerdown);
			this.canvas.parentNode.removeChild(this.canvas);

			this.__listeners.pointerdown = null;
			this.__listeners.pointermove = null;

		}

		this.running = false;

	},

	Feel: function(state, timeout) {

		timeout = typeof timeout === "number" ? timeout : null;

		if (this.feeling != state) {

			let old_state = this.state;

			if (this.statemap[old_state] !== undefined) {
				this.statemap[old_state]["start"] = null;
				this.statemap[old_state]["end"]   = null;
			}

			if (this.debug === true) {

				if (timeout !== null) {
					console.log("Feel(): Change " + this.feeling + " to " + state + " for " + timeout.toString() + "ms");
				} else {
					console.log("Feel(): Change " + this.feeling + " to " + state + " indefinitely");
				}

			}

			this.feeling = state;

			if (this.statemap[state] !== undefined) {

				this.statemap[state]["start"] = Date.now();

				if (state === "okay") {

					if (timeout === null) {
						timeout = 1000;
					}

					this.statemap[state]["end"] = Date.now() + timeout;

				} else if (state === "angry") {

					if (timeout === null) {
						this.statemap[state]["end"] = null;
					} else {
						this.statemap[state]["end"] = Date.now() + timeout;
					}

				} else if (state === "sick") {

					if (timeout === null) {
						timeout = 1000;
					}

					this.statemap[state]["end"] = Date.now() + timeout;

				} else if (state === "vomit") {

					if (timeout === null) {
						timeout = 1000;
					}

					this.statemap[state]["end"] = Date.now() + timeout;

				}

			}

			if (timeout !== null) {

				setTimeout(() => {

					this.statemap[this.feeling]["start"] = null;
					this.statemap[this.feeling]["end"]   = null;
					this.feeling = "okay";

				}, timeout);

			}

			return true;

		} else {
			return false;
		}

	},

	Init: function() {

		if (this.canvas.parentNode === null && this.figure !== null) {

			this.ResizeTo(this.width, this.height);

			this.__listeners.pointerdown = () => {

				if (this.IsRunning() === true && this.IsFeeling("angry") === false) {

					let count = this.Increase("angry");
					if (count >= 6) {

						this.OnGameStart("level1");

					} else if (count == 5) {

						this.Feel("angry", 900);
						PlaySound("ouch");

					} else if (count == 4) {

						this.Speak("angry2", () => {
							this.Feel("okay");
						});

					} else if (count == 3) {

						this.Feel("angry", 900);
						PlaySound("ouch");

					} else if (count == 2) {

						this.Speak("angry1", () => {
							this.Feel("okay");
						});

					} else {

						this.Feel("angry", 900);
						PlaySound("ouch");

					}

				}

			};

			this.__listeners.pointermove = (event) => {

				if (this.IsRunning() === true) {

					let rect = this.canvas.getBoundingClientRect();
					let px   = event.clientX - rect.left - 16;
					let py   = event.clientY - rect.top  - 16;

					this.LookAt(px, py);

				}

			};

			this.canvas.addEventListener("pointerdown", this.__listeners.pointerdown, true);
			document.body.addEventListener("pointermove", this.__listeners.pointermove, true);

			this.figure.appendChild(this.canvas);

		}

	},

	Increase: function(state) {

		let amount = this.progress[state] || 0;

		amount++;
		this.progress[state] = amount;

		return amount;

	},

	IsFeeling: function(state) {
		return this.feeling === state;
	},

	IsRunning: function() {
		return this.running === true;
	},

	IsSpeaking: function() {
		return this.speaking["start"] !== null;
	},

	LookAt: function(px, py) {

		if (this.speaking["start"] !== null) {

			if (this.focus.x !== null) {
				this.focus.dx = px - this.focus.x;
			}

			if (this.focus.y !== null) {
				this.focus.dy = py - this.focus.y;
			}

			this.focus.x = px;
			this.focus.y = py;

		} else {

			if (this.focus.x !== null) {
				this.focus.dx = px - this.focus.x;
			}

			if (this.focus.y !== null) {
				this.focus.dy = py - this.focus.y;
			}

			this.focus.x = px;
			this.focus.y = py;

			if (this.IsGameRunning() === false) {

				if (this.feeling === "okay") {

					this.statemap["sick"]["nausea"] += 1;

					if (this.statemap["sick"]["nausea"] > 10) {
						this.feeling = "sick";
						this.statemap["sick"]["start"] = Date.now();
					}

				} else if (this.feeling === "sick") {

					this.statemap["sick"]["nausea"] += 1;

					if (this.statemap["sick"]["nausea"] >= 100) {

						this.statemap["sick"]["start"] = null;
						this.statemap["sick"]["nausea"] = 0;

						this.feeling = "vomit";
						this.statemap["vomit"]["start"] = Date.now();
						this.statemap["vomit"]["end"] = Date.now() + 500;

						PlaySound("vomit");

						setTimeout(() => {

							this.statemap["vomit"]["start"] = null;
							this.statemap["vomit"]["end"] = null;

							this.statemap["sick"]["start"] = null;
							this.statemap["sick"]["nausea"] = 0;

							this.feeling = "okay";

						}, 500);

					}

				}

			}

		}

	},

	Render: function(delta) {

		this.context.clearRect(0, 0, this.width, this.height);

		DrawFace(this.context, this.width, this.height, this.feeling, this.statemap[this.feeling] || {});

		DrawEyeBall(this.context, "left", this.focus, this.feeling);
		DrawEyeBall(this.context, "right", this.focus, this.feeling);
		DrawEyePupil(this.context, "left", this.focus, this.feeling);
		DrawEyePupil(this.context, "right", this.focus, this.feeling);

		if (this.speaking["phoneme"] !== "") {
			DrawMouthPhoneme(this.context, this.speaking["phoneme"], this.speaking, this.debug);
		} else if (this.feeling === "okay" || this.feeling === "sick") {
			DrawMouthExpression(this.context, this.feeling, this.statemap["sick"], this.debug);
		} else if (this.feeling === "angry") {
			DrawMouthExpression(this.context, this.feeling, this.statemap["angry"], this.debug);
		} else if (this.feeling === "vomit") {
			DrawMouthExpression(this.context, this.feeling, this.statemap["vomit"], this.debug);
		} else {
			DrawMouthExpression(this.context, this.feeling, null, this.debug);
		}

		if (this.feeling === "vomit") {

			let rect = this.canvas.getBoundingClientRect();

			DrawVomit({
				x: this.focus.x - window.scrollX + rect.left,
				y: this.focus.y - window.scrollY + rect.top,
			}, this.feeling, this.statemap[this.feeling] || {}, delta);

		} else {

			ClearVomit();

		}

	},

	ResizeTo: function(width, height) {

		this.canvas.width  = width;
		this.canvas.height = height;

		this.canvas.style.width = width + "px";
		this.canvas.style.height = height + "px";

	},

	Speak: function(identifier, callback) {

		callback = typeof callback === "function" ? callback : null;

		let [ /*buffer*/, speech ] = GetSpeech(identifier);

		if (speech !== null && this.IsSpeaking() === false) {

			if (this.debug === true) {
				console.log("Speak(): Speak " + identifier + " for " + speech["length"] + "ms");
			}

			if (identifier.startsWith("angry") === true) {
				this.Feel("angry", speech["length"]);
			}

			this.speaking["start"]   = Date.now();
			this.speaking["index"]   = 0;
			this.speaking["phoneme"] = "";
			this.speaking["speech"]  = speech;

			let interval = setInterval(() => {

				if (this.speaking["start"] === null) {

					if (this.IsGameRunning() === false) {
						this.feeling = "okay";
					}

				} else {

					let dt = Date.now() - this.speaking["start"];
					if (dt >= this.speaking["speech"]["length"]) {

						this.speaking["start"]   = null;
						this.speaking["index"]   = 0;
						this.speaking["phoneme"] = "";
						this.speaking["speech"]  = null;

						if (this.IsGameRunning() === false) {
							this.feeling = "okay";
						}

					} else {

						let timeline = this.speaking["speech"]["timeline"] || [];
						let index    = 0;

						for (let t = 0, tl = timeline.length; t < tl; t++) {

							if (dt >= timeline[t]) {
								index = t;
							} else {
								break;
							}

						}

						this.speaking["index"]   = index;
						this.speaking["phoneme"] = this.speaking["speech"]["phonemes"][index] || "";

					}

				}

			}, 1000 / 60);

			PlaySpeech(identifier, () => {

				this.speaking["start"]   = null;
				this.speaking["index"]   = 0;
				this.speaking["phoneme"] = "";
				this.speaking["speech"]  = null;

				clearInterval(interval);

				if (callback !== null) {
					callback();
				}

			});

		}

	},

	Start: function() {

		this.running = true;

		let last_time   = Date.now();
		let render_loop = () => {

			let delta = Date.now() - last_time;

			if (this.running === true) {
				this.Render(delta);
				requestAnimationFrame(render_loop);
			}

		};

		let update_loop = setInterval(() => {

			let now   = Date.now();
			let delta = now - last_time;

			if (this.running === true) {
				this.Update(delta);
			} else {
				clearInterval(update_loop);
			}

			last_time = now;

		}, 1000 / 30);

		render_loop();

	},

	Stop: function() {

		this.running = false;

	},

	Update: function(delta) {

		let dt     = delta / 1000;
		let nausea = this.statemap["sick"]["nausea"];

		if (nausea > 0) {

			this.statemap["sick"]["nausea"] -= dt * 50;

			if (this.statemap["sick"]["nausea"] < 0) {
				this.statemap["sick"]["nausea"] = 0;
			}

		}

	}

};

