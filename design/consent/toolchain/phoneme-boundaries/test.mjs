
import { SpeechDebugger     } from "./avatar/debug/SpeechDebugger.mjs";
import { GetSpeech          } from "./common/speech/GetSpeech.mjs";
import { LoadSpeech         } from "./common/speech/LoadSpeech.mjs";
import { ParsePhonemes      } from "./common/speech/ParsePhonemes.mjs";
import { generatePhonemeTimeline } from "./generatePhonemeTimeline.mjs";
import { DrawPhonemeTimeline } from "./avatar/debug/DrawPhonemeTimeline.mjs";

(() => {

	const base    = new URL(".", import.meta.url);
	const wrapper = document.querySelector("article section#speeches");

	Promise.all([

		// Avatar Speeches
		LoadSpeech("game-level1", new URL("./game/speeches/game-level1.json", base), [ new URL("./game/speeches/game-level1.mp3", base) ]),
		LoadSpeech("game-level2", new URL("./game/speeches/game-level2.json", base), [ new URL("./game/speeches/game-level2.mp3", base) ]),
		LoadSpeech("game-level3", new URL("./game/speeches/game-level3.json", base), [ new URL("./game/speeches/game-level3.mp3", base) ]),
		LoadSpeech("game-over",   new URL("./game/speeches/game-over.json", base),   [ new URL("./game/speeches/game-over.mp3", base) ]),
		LoadSpeech("consent",     new URL("./game/speeches/consent.json", base),     [ new URL("./game/speeches/consent.mp3", base) ]),

	]).then(() => {

		[
			"game-level1",
			"game-level2",
			"game-level3",
			"game-over",
			"consent"
		].forEach((identifier) => {

			let [ buffer, speech, config ] = GetSpeech(identifier);

			if (buffer !== null && speech !== null && config !== null) {

				let speech_debugger = new SpeechDebugger(identifier, buffer, speech, config);

				let query = window.location.search || "";
				if (query.includes("?debug") || query.includes("&debug")) {

					if (window.DEBUGGERS === undefined) {
						window.DEBUGGERS = {};
					}

					window.DEBUGGERS[identifier] = speech_debugger;

				}

				const phoneme_map = {};

				config["sentence"].forEach((word) => {

					if (word !== "." && word !== "?" && word !== "!") {
						phoneme_map[word] = ParsePhonemes(word);
					}

				});

				// Detect phoneme boundaries first
				const options = {
					frameSize: 512, // ~11ms
					hopSize:   256,
					energyThreshold:   0.05, // 0.01 (every fluctuation) to 1.0 (nothing triggers it)
					centroidThreshold: 1000, // 1000 - 5000 Hz for speech
					zcrThreshold:      0.05  // 0 (everything triggers), 0.05-0.1 (speech), above 0.2 (ignores everything)
				};

				const phoneme_timeline = generatePhonemeTimeline(buffer, config, phoneme_map, options);

				DrawPhonemeTimeline(speech_debugger.canvas.getContext("2d"), speech_debugger.scale, phoneme_timeline);

				console.log(phoneme_timeline);

				wrapper.appendChild(speech_debugger.canvas);

			} else {
				console.error("Incomplete Speech \"" + identifier + "\"");
			}

		});

	}).catch((err) => {
		console.error(err);
	});

})();
