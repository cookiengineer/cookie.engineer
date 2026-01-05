
import { Avatar     } from "./Avatar.mjs";
import { LoadSound  } from "../common/sound/LoadSound.mjs";
import { LoadSpeech } from "../common/speech/LoadSpeech.mjs";

export const Init = (figure) => {

	figure = typeof figure === "object" ? figure : null;

	const base = new URL(".", import.meta.url);

	return new Promise((resolve, reject) => {

		return Promise.all([
			LoadSound("burp",  [ new URL("./sounds/burp.m4a", base),  new URL("./sounds/burp.mp3", base),  new URL("./sounds/burp.opus", base) ]),
			LoadSound("ouch",  [ new URL("./sounds/ouch.m4a", base),  new URL("./sounds/ouch.mp3", base),  new URL("./sounds/ouch.opus", base) ]),
			LoadSound("vomit", [ new URL("./sounds/vomit.m4a", base), new URL("./sounds/vomit.mp3", base), new URL("./sounds/vomit.opus", base) ]),
			LoadSpeech("angry1", new URL("./speeches/angry1.json", base), [ new URL("./speeches/angry1.m4a", base), new URL("./speeches/angry1.mp3", base), new URL("./speeches/angry1.opus", base) ]),
			LoadSpeech("angry2", new URL("./speeches/angry2.json", base), [ new URL("./speeches/angry2.m4a", base), new URL("./speeches/angry2.mp3", base), new URL("./speeches/angry2.opus", base) ]),
		]).then(() => {

			if (figure !== null) {

				let width  = 256;
				let height = 256;

				let image = figure.querySelector("img");
				if (image !== null) {

					let width  = Number.parseInt(image.getAttribute("width"),  10);
					let height = Number.parseInt(image.getAttribute("height"), 10);

					if (Number.isNaN(width) === true) {
						width = 256;
					}

					if (Number.isNaN(height) === true) {
						height = 256;
					}

				}

				let avatar = new Avatar(figure, width, height);

				avatar.Init();
				avatar.Start();

				resolve(avatar);

			} else {
				reject(new Error("Invalid <figure> element parameter, cannot create Avatar"));
			}

		}).catch((err) => {
			reject(err);
		});

	});

};
