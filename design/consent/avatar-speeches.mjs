
import { SpeechDebugger     } from "./avatar/debug/SpeechDebugger.mjs";
import { GetSpeech          } from "./common/speech/GetSpeech.mjs";
import { LoadSpeech         } from "./common/speech/LoadSpeech.mjs";
import { Init as InitAvatar } from "./avatar/Init.mjs";

(() => {

	const base    = new URL(".", import.meta.url);
	const figure  = document.querySelector("figure#avatar");
	const wrapper = document.querySelector("article section#speeches");

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

		return Promise.all([

			// Avatar Speeches
			LoadSpeech("angry1", new URL("./avatar/speeches/angry1.json", base), [ new URL("./avatar/speeches/angry1.mp3", base) ]),
			LoadSpeech("angry2", new URL("./avatar/speeches/angry2.json", base), [ new URL("./avatar/speeches/angry2.mp3", base) ]),
			LoadSpeech("angry3", new URL("./avatar/speeches/angry3.json", base), [ new URL("./avatar/speeches/angry3.mp3", base) ]),

			// Game Speeches
			LoadSpeech("consent",         new URL("./game/speeches/consent.json",         base), [ new URL("./game/speeches/consent.mp3",         base) ]),
			LoadSpeech("game-level1",     new URL("./game/speeches/game-level1.json",     base), [ new URL("./game/speeches/game-level1.mp3",     base) ]),
			LoadSpeech("game-level2",     new URL("./game/speeches/game-level2.json",     base), [ new URL("./game/speeches/game-level2.mp3",     base) ]),
			LoadSpeech("game-level3",     new URL("./game/speeches/game-level3.json",     base), [ new URL("./game/speeches/game-level3.mp3",     base) ]),
			LoadSpeech("game-over",       new URL("./game/speeches/game-over.json",       base), [ new URL("./game/speeches/game-over.mp3",       base) ]),
			LoadSpeech("game-secret",     new URL("./game/speeches/game-secret.json",     base), [ new URL("./game/speeches/game-secret.mp3",     base) ]),
			LoadSpeech("me-want-cookies", new URL("./game/speeches/me-want-cookies.json", base), [ new URL("./game/speeches/me-want-cookies.mp3", base) ]),
			LoadSpeech("no-consent",      new URL("./game/speeches/no-consent.json",      base), [ new URL("./game/speeches/no-consent.mp3",      base) ])

		]).then(() => {

			[
				"angry1",
				"angry2",
				"angry3",
				"consent",
				"game-level1",
				"game-level2",
				"game-level3",
				"game-over",
				"game-secret",
				"me-want-cookies",
				"no-consent"
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

					wrapper.appendChild(speech_debugger.canvas);

				} else {
					console.error("Incomplete Speech \"" + identifier + "\"");
				}

			});

		}).catch((err) => {
			console.error(err);
		});

	});

})();
