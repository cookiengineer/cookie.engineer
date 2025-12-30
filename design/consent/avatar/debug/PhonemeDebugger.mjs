
import { GetImage          } from "../../common/image/GetImage.mjs";
import { DrawEyeBall       } from "../draw/DrawEyeBall.mjs";
import { DrawEyePupil      } from "../draw/DrawEyePupil.mjs";
import { DrawFace          } from "../draw/DrawFace.mjs";
import { DrawMouthCenter   } from "./DrawMouthCenter.mjs";
import { DrawMouthPhoneme  } from "../draw/DrawMouthPhoneme.mjs";
import { DrawPhonemeHelper } from "./DrawPhonemeHelper.mjs";
import { DrawPhonemeRuler  } from "./DrawPhonemeRuler.mjs";
import { DrawPhonemeSketch } from "./DrawPhonemeSketch.mjs";

export const PhonemeDebugger = function(identifier, phonemes) {

	this.phonemes     = phonemes;
	this.sketch_image = GetImage("PhonemeSketch");

	this.canvas = document.createElement("canvas");
	this.canvas.setAttribute("id", "phoneme-" + identifier);
	this.canvas.className = "phoneme-debugger";

	this.context = this.canvas.getContext("2d");
	this.scale   = 1.0;
	this.focus   = {
		x: null,
		y: null
	};
	this.mouth   = {
		x: 115,
		y: 180
	};
	this.helpers  = {
		"ruler": {
			color: "#0fff0f"
		},
		"distanceat": {
			color:    "#ffff0f",
			position: { x: 0, y: 0 }
		},
		"mouseat": {
			color:    "#ff0f0f",
			position: { x: 0, y: 0 }
		}
	};
	this.speaking = {
		"start":   null,
		"index":   0,
		"phoneme": this.phonemes[0] || "",
		"speech":  null
	};

	this.canvas.addEventListener("click", (event) => {

		let rect  = this.canvas.getBoundingClientRect();
		let pos_x = event.clientX - rect.left;
		let pos_y = event.clientY - rect.top;

		if (event.shiftKey === true) {

			this.DistanceAt(0, 0);
			this.Render();

		} else {

			this.DistanceAt(pos_x, pos_y);
			this.Render();

		}

	});

	this.canvas.addEventListener("mousemove", (event) => {

		let rect  = this.canvas.getBoundingClientRect();
		let pos_x = event.clientX - rect.left;
		let pos_y = event.clientY - rect.top;

		this.focus.x = pos_x;
		this.focus.y = pos_y;
		this.helpers["mouseat"].position.x = pos_x;
		this.helpers["mouseat"].position.y = pos_y;
		this.Render();

	});

	this.Resize();
	this.Render();

};

PhonemeDebugger.prototype = {

	Render: function() {

		this.context.fillStyle = "#151515";
		this.context.fillRect(0, 0, this.canvas.width, this.canvas.height);

		DrawFace(this.context, 256, 256, "okay", null);

		DrawEyeBall(this.context, "left", this.focus, "okay");
		DrawEyeBall(this.context, "right", this.focus, "okay");
		DrawEyePupil(this.context, "left", this.focus, "okay");
		DrawEyePupil(this.context, "right", this.focus, "okay");

		DrawPhonemeSketch(this.context, this.sketch_image, this.speaking["phoneme"], this.mouth);
		DrawMouthCenter(this.context, this.mouth);

		DrawMouthPhoneme(this.context, this.speaking["phoneme"], this.speaking, true);

		this.context.font = "16px vera-mono";
		this.context.fillStyle = "#ffffff";
		this.context.fillText("Phonemes: " + this.phonemes.join(" "), 4, 16);

		if (this.helpers["distanceat"].position.x > 0 && this.helpers["distanceat"].position.y > 0) {

			if (this.helpers["mouseat"].position.x > 0 && this.helpers["mouseat"].position.y > 0) {
				DrawPhonemeRuler(this.context, this.scale, this.helpers["distanceat"].position, this.helpers["mouseat"].position, this.helpers["ruler"].color, this.helpers["distanceat"].color, this.helpers["mouseat"].color);
			} else {
				DrawPhonemeHelper(this.context, this.scale, this.helpers["distanceat"].position, this.helpers["distanceat"].color);
			}

		} else {

			if (this.helpers["mouseat"].position.x > 0 && this.helpers["mouseat"].position.y > 0) {
				DrawPhonemeHelper(this.context, this.scale, this.helpers["mouseat"].position, this.helpers["mouseat"].color);
			}

		}

	},

	Resize: function() {

		let width  = (256 * this.scale) | 0;
		let height = (256 * this.scale) | 0;

		this.canvas.width  = width;
		this.canvas.height = height;

		this.canvas.style.width  = width  + "px";
		this.canvas.style.height = height + "px";

	},

	DistanceAt: function(position_x, position_y) {

		console.log("DistanceAt(): Place Distance marker at x=" + position_x + "px and y=" + position_y + "px");

		this.helpers["distanceat"].position.x = position_x;
		this.helpers["distanceat"].position.y = position_y;

	}

};
