
import { DrawSpeech         } from "./DrawSpeech.mjs";
import { DrawSpeechConfig   } from "./DrawSpeechConfig.mjs";
import { DrawSpeechHelper   } from "./DrawSpeechHelper.mjs";
import { DrawSpeechWavedata } from "./DrawSpeechWavedata.mjs";

const audio_context = new AudioContext();

export const SpeechDebugger = function(identifier, buffer, speech, config) {

	this.identifier = identifier;
	this.buffer     = buffer;
	this.config     = config;
	this.speech     = speech;
	this.wavedata   = buffer.getChannelData(0);

	this.canvas = document.createElement("canvas");
	this.canvas.setAttribute("id", "speech-" + identifier);
	this.canvas.className = "speech-debugger";

	this.context  = this.canvas.getContext("2d");
	this.scale    = 0.5;
	this.source   = null;
	this.playback = {
		start:  null,
		stop:   null
	};
	this.timers = {
		start: null,
		stop:  null
	};

	this.helpers = {
		"playback": {
			color:    "#ff0f0f",
			position: 0
		},
		"mouseat": {
			color:    "#0fff0f",
			position: 0
		},
		"playat": {
			color:    "#ffff0f",
			position: 0
		},
		"stopat": {
			color:    "#ffff0f",
			position: 0
		}
	};

	this.canvas.addEventListener("click", (event) => {

		let rect  = this.canvas.getBoundingClientRect();
		let pos_x = event.clientX - rect.left;

		if (event.ctrlKey === true) {

			this.StopAt(pos_x);
			this.Render();

		} else if (event.shiftKey === true) {

			this.StopAt(0);
			this.Render();

		} else {

			this.PlayAt(pos_x);
			this.Render();

		}

	});

	this.canvas.addEventListener("mousemove", (event) => {

		let rect  = this.canvas.getBoundingClientRect();
		let pos_x = event.clientX - rect.left;

		this.helpers["mouseat"].position = pos_x;
		this.Render();

	});

	this.Resize();
	this.Render();

};

SpeechDebugger.prototype = {

	PlayAt: function(position_x) {

		if (this.source !== null) {

			this.source.stop();

			setTimeout(() => {
				this.PlayAt(position_x);
			}, 100);

			return;

		}

		let current_time = (position_x / this.canvas.width) * this.buffer.duration;

		console.log("PlayAt(): Start playback at " + ((current_time * 1000) | 0) + "ms for x=" + position_x + "px");

		this.helpers["playat"].position = position_x;

		this.playback.start = current_time;
		this.timers.start = Date.now() - current_time * 1000;

		if (this.playback.stop !== null) {
			this.timers.stop = Date.now() - (current_time * 1000) + (this.playback.stop * 1000);
		} else {
			this.timers.stop = null;
		}

		this.source = audio_context.createBufferSource();
		this.source.buffer = this.buffer;
		this.source.connect(audio_context.destination);
		this.source.onended = () => {

			this.helpers["playback"].position = 0;

			this.timers.start = null;
			this.timers.stop  = null;
			this.source       = null;

		};

		this.source.start(0, current_time);

		let update_loop = () => {

			if (this.timers.start !== null) {

				let pos_x = (((Date.now() - this.timers.start) / 1000) / this.buffer.duration) * this.canvas.width;

				this.helpers["playback"].position = pos_x;
				this.Render();

				if (this.timers.stop !== null) {

					if (Date.now() > this.timers.stop) {

						if (this.source !== null) {
							this.source.stop();
						}

					}

				}

				requestAnimationFrame(update_loop);

			}

		};

		requestAnimationFrame(update_loop);

	},

	StopAt: function(position_x) {

		if (position_x > 0) {

			let current_time = (position_x / this.canvas.width) * this.buffer.duration;

			console.log("StopAt(): Change marker to " + (current_time * 1000) + "ms for x=" + position_x + "px");

			this.playback.stop = current_time;
			this.helpers["stopat"].position = position_x;
			this.Render();

		} else {

			console.log("StopAt(): Change marker to " + (this.buffer.duration * 1000) + "ms");

			this.playback.stop = null;
			this.helpers["stopat"].position = this.canvas.width;
			this.Render();

		}

	},

	Render: function() {

		this.context.fillStyle = "#151515";
		this.context.fillRect(0, 0, this.canvas.width, this.canvas.height);

		DrawSpeechWavedata(this.context, this.identifier, this.scale, this.speech, this.wavedata);
		DrawSpeech(this.context, this.identifier, this.scale, this.speech, this.buffer.duration);
		DrawSpeechConfig(this.context, this.identifier, this.scale, this.speech, this.config);

		if (this.helpers["playback"].position > 0) {
			DrawSpeechHelper(this.context, this.scale, this.helpers["playback"].position, this.helpers["playback"].color);
		}

		if (this.helpers["playat"].position >= 0 && this.helpers["playat"].position < this.canvas.width) {
			DrawSpeechHelper(this.context, this.scale, this.helpers["playat"].position, this.helpers["playat"].color);
		}

		if (this.helpers["stopat"].position > 0 && this.helpers["stopat"].position < this.canvas.width) {
			DrawSpeechHelper(this.context, this.scale, this.helpers["stopat"].position, this.helpers["stopat"].color);
		}

		if (this.helpers["mouseat"].position > 0 && this.helpers["mouseat"].position < this.canvas.width) {
			DrawSpeechHelper(this.context, this.scale, this.helpers["mouseat"].position, this.helpers["mouseat"].color);
		}

	},

	Resize: function() {

		let width  = (this.speech["length"] * this.scale) | 0;
		let height = 128;

		this.canvas.width  = width;
		this.canvas.height = height;

		this.canvas.style.width  = width  + "px";
		this.canvas.style.height = height + "px";

	}

};
