
import { LoadImage          } from "./common/image/LoadImage.mjs";
import { Init as InitAvatar } from "./avatar/Init.mjs";
import { GetSpeech          } from "./common/speech/GetSpeech.mjs";
import { InjectSpeech       } from "./common/speech/InjectSpeech.mjs";
import { ParseSpeech        } from "./common/speech/ParseSpeech.mjs";
import { PhonemeDebugger    } from "./avatar/debug/PhonemeDebugger.mjs";

(() => {

	const base    = new URL(".", import.meta.url);
	const figure  = document.querySelector("figure#avatar");
	const wrapper = document.querySelector("article section#phonemes");

	InitAvatar(figure).then((avatar) => {

		avatar.IsGameRunning = () => {
			return false;
		};

		avatar.OnGameStart = () => {
			console.info("Start Game now!");
		};

		let query = window.location.search || "";
		if (query.includes("?debug") || query.includes("&debug")) {
			window.AVATAR = avatar;
			window.AVATAR.debug = true;
		}

		let input     = document.querySelector("article section#debugger input");
		let speak     = document.querySelector("article section#debugger button[data-action=\"speak\"]");
		let pronounce = document.querySelector("article section#debugger button[data-action=\"pronounce\"]");

		if (input !== null && speak !== null) {

			speak.addEventListener("click", () => {

				let raw_sentence = (input.value || "").trim();
				if (raw_sentence !== "") {

					let sentence = raw_sentence.toLowerCase().split(" ");
					if (sentence.length > 0) {

						let last_word = sentence[sentence.length - 1];
						if (last_word.endsWith(".") || last_word.endsWith("?") || last_word.endsWith("!")) {
							sentence.push(last_word.substr(last_word.length - 1, 1));
							sentence[sentence.length - 2] = last_word.substr(0, last_word.length - 1);
						} else if (last_word !== "." && last_word !== "?" && last_word !== "!") {
							sentence.push(".");
						}

					}

					let sample_rate   = new AudioContext().sampleRate;
					let frames        = Math.ceil(sentence.length * 200 / 1000) * sample_rate;
					let audio_context = new OfflineAudioContext(1, frames, sample_rate);
					let buffer        = audio_context.createBuffer(1, frames, sample_rate);
					let timeline      = sentence.map((word, w) => {
						return w * 200;
					});

					let config = {
						"sentence": sentence,
						"timeline": timeline,
						"length":   500 + sentence.length * 200
					};

					let speech = ParseSpeech(config);

					console.group("Injected Speech")
					console.log("AudioBuffer", buffer);
					console.log("Speech", speech);
					console.log("Config", config);
					console.groupEnd();

					InjectSpeech("debug", buffer, speech, config);

					avatar.Speak("debug", () => {
						console.log("FINISHED");
					});

				}

			});

		}

		if (input !== null && pronounce !== null) {

			pronounce.addEventListener("click", () => {

				let raw_sentence = (input.value || "").trim();
				if (raw_sentence !== "") {

					let sentence = raw_sentence.toLowerCase().split(" ");
					if (sentence.length > 0) {

						let last_word = sentence[sentence.length - 1];
						if (last_word.endsWith(".") || last_word.endsWith("?") || last_word.endsWith("!")) {
							sentence.push(last_word.substr(last_word.length - 1, 1));
							sentence[sentence.length - 2] = last_word.substr(0, last_word.length - 1);
						} else if (last_word !== "." && last_word !== "?" && last_word !== "!") {
							sentence.push(".");
						}

					}

					let sample_rate   = new AudioContext().sampleRate;
					let frames        = Math.ceil(sentence.length * 2000 / 1000) * sample_rate;
					let audio_context = new OfflineAudioContext(1, frames, sample_rate);
					let buffer        = audio_context.createBuffer(1, frames, sample_rate);
					let timeline      = sentence.map((word, w) => {
						return w * 2000;
					});

					let config = {
						"sentence": sentence,
						"timeline": timeline,
						"length":   500 + sentence.length * 2000
					};

					let speech = ParseSpeech(config);

					InjectSpeech("debug", buffer, speech, config);

					console.group("Injected Speech")
					console.log("AudioBuffer", buffer);
					console.log("Speech", speech);
					console.log("Config", config);
					console.groupEnd();

					avatar.Speak("debug", () => {
						console.log("FINISHED");
					});

				}

			});

		}

		return Promise.all([

			LoadImage("PhonemeSketch", new URL("./avatar/debug/PhonemeSketch.png", base))

		]).then((image) => {

			[
				[ "AE", "AE0", "AE1", "AE2", "EH", "EH0", "EH1", "EH2" ],
				[ "AO", "AO0", "AO1", "AO2", "OW", "OW0", "OW1", "OW2" ],
				[ "UH", "UH0", "UH1", "UH2", "UW", "UW0", "UW1", "UW2", "AW", "AW0", "AW1", "AW2" ],
				[ "D", "N", "S", "Z" ],
				[ "G", "K" ],
				[ "L", "R", "ER", "ER0", "ER1", "ER2" ],
				[ "B", "M", "P" ],
				[ "F", "V" ],
				[ "IH", "IH0", "IH1", "IH2", "IY", "IY0", "IY1", "IY2" ],
				[ "T", "TH", "DH", "HH" ],
				[ "CH", "SH", "JH", "ZH" ],
				[ "W", "Y" ]
			].forEach((phoneme_group) => {

				let identifier       = phoneme_group.join("_");
				let phoneme_debugger = new PhonemeDebugger(identifier, phoneme_group);

				let query = window.location.search || "";
				if (query.includes("?debug") || query.includes("&debug")) {

					if (window.DEBUGGERS === undefined) {
						window.DEBUGGERS = {};
					}

					window.DEBUGGERS[identifier] = phoneme_debugger;

				}

				wrapper.appendChild(phoneme_debugger.canvas);

			});

		}).catch((err) => {
			console.error(err);
		});

	});

})();
