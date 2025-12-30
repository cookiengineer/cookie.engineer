
import { Avatar     } from "../avatar/Avatar.mjs";
import { Game       } from "./Game.mjs";
import { LoadImage  } from "../common/image/LoadImage.mjs";
import { LoadMusic  } from "../common/music/LoadMusic.mjs";
import { LoadSound  } from "../common/sound/LoadSound.mjs";
import { LoadSpeech } from "../common/speech/LoadSpeech.mjs";

export const Init = (avatar, wrapper) => {

	avatar  = typeof avatar === "object" && avatar instanceof Avatar ? avatar  : null;
	wrapper = typeof wrapper === "object"                            ? wrapper : null;

	const base = new URL(".", import.meta.url);

	return new Promise((resolve, reject) => {

		return Promise.all([

			LoadMusic("game-boss",   [ new URL("./music/game-boss.m4a", base),   new URL("./music/game-boss.mp3", base),   new URL("./music/game-boss.opus", base)   ]),
			LoadMusic("game-level",  [ new URL("./music/game-level.m4a", base),  new URL("./music/game-level.mp3", base),  new URL("./music/game-level.opus", base)  ]),
			LoadMusic("game-over",   [ new URL("./music/game-over.m4a", base),   new URL("./music/game-over.mp3", base),   new URL("./music/game-over.opus", base)   ]),
			LoadMusic("game-secret", [ new URL("./music/game-secret.m4a", base), new URL("./music/game-secret.mp3", base), new URL("./music/game-secret.opus", base) ]),
			LoadMusic("game-start",  [ new URL("./music/game-start.m4a", base),  new URL("./music/game-start.mp3", base),  new URL("./music/game-start.opus", base)  ]),

			// Game Sounds
			LoadSound("damage",    [ new URL("./sounds/damage.m4a", base),    new URL("./sounds/damage.mp3", base),    new URL("./sounds/damage.opus", base)    ]),
			LoadSound("explosion", [ new URL("./sounds/explosion.m4a", base), new URL("./sounds/explosion.mp3", base), new URL("./sounds/explosion.opus", base) ]),
			LoadSound("lazer",     [ new URL("./sounds/lazer.m4a", base),     new URL("./sounds/lazer.mp3", base),     new URL("./sounds/lazer.opus", base)     ]),
			LoadSound("ripple",    [ new URL("./sounds/ripple.m4a", base),    new URL("./sounds/ripple.mp3", base),    new URL("./sounds/ripple.opus", base)    ]),

			LoadSpeech("consent",         new URL("./speeches/consent.json", base),         [ new URL("./speeches/consent.m4a", base),         new URL("./speeches/consent.mp3", base),         new URL("./speeches/consent.opus", base)         ]),
			LoadSpeech("game-level1",     new URL("./speeches/game-level1.json", base),     [ new URL("./speeches/game-level1.m4a", base),     new URL("./speeches/game-level1.mp3", base),     new URL("./speeches/game-level1.opus", base)     ]),
			LoadSpeech("game-level2",     new URL("./speeches/game-level2.json", base),     [ new URL("./speeches/game-level2.m4a", base),     new URL("./speeches/game-level2.mp3", base),     new URL("./speeches/game-level2.opus", base)     ]),
			LoadSpeech("game-level3",     new URL("./speeches/game-level3.json", base),     [ new URL("./speeches/game-level3.m4a", base),     new URL("./speeches/game-level3.mp3", base),     new URL("./speeches/game-level3.opus", base)     ]),
			LoadSpeech("game-over",       new URL("./speeches/game-over.json", base),       [ new URL("./speeches/game-over.m4a", base),       new URL("./speeches/game-over.mp3", base),       new URL("./speeches/game-over.opus", base)       ]),
			LoadSpeech("game-secret",     new URL("./speeches/game-secret.json", base),     [ new URL("./speeches/game-secret.m4a", base),     new URL("./speeches/game-secret.mp3", base),     new URL("./speeches/game-secret.opus", base)     ]),
			LoadSpeech("me-want-cookies", new URL("./speeches/me-want-cookies.json", base), [ new URL("./speeches/me-want-cookies.m4a", base), new URL("./speeches/me-want-cookies.mp3", base), new URL("./speeches/me-want-cookies.opus", base) ]),
			LoadSpeech("no-consent",      new URL("./speeches/no-consent.json", base),      [ new URL("./speeches/no-consent.m4a", base),      new URL("./speeches/no-consent.mp3", base),      new URL("./speeches/no-consent.opus", base)      ]),

			// Game Entities
			LoadImage("gui/Status",          new URL("./entities/gui/Status.png", base)         ),
			LoadImage("Cookie",              new URL("./entities/Cookie.png", base)             ),
			LoadImage("Explosion",           new URL("./entities/Explosion.png", base)          ),
			LoadImage("MeteorSand",          new URL("./entities/MeteorSand.png", base)         ),
			LoadImage("MeteorStone",         new URL("./entities/MeteorStone.png", base)        ),
			LoadImage("Spaceship",           new URL("./entities/Spaceship.png", base)          ),
			LoadImage("StarDestroyer",       new URL("./entities/StarDestroyer.png", base)      ),
			LoadImage("StarDestroyerCannon", new URL("./entities/StarDestroyerCannon.png", base)),

			// Game Entity Sounds
			LoadSound("CookieEngineerCharge",      [ new URL("./entities/CookieEngineerCharge.m4a", base),      new URL("./entities/CookieEngineerCharge.mp3", base),      new URL("./entities/CookieEngineerCharge.opus", base)      ]),
			LoadSound("CookieEngineerLightning",   [ new URL("./entities/CookieEngineerLightning.m4a", base),   new URL("./entities/CookieEngineerLightning.mp3", base),   new URL("./entities/CookieEngineerLightning.opus", base)   ]),
			LoadSound("StarDestroyerCannonCharge", [ new URL("./entities/StarDestroyerCannonCharge.m4a", base), new URL("./entities/StarDestroyerCannonCharge.mp3", base), new URL("./entities/StarDestroyerCannonCharge.opus", base) ]),
			LoadSound("StarDestroyerCannonLazer",  [ new URL("./entities/StarDestroyerCannonLazer.m4a", base),  new URL("./entities/StarDestroyerCannonLazer.mp3", base),  new URL("./entities/StarDestroyerCannonLazer.opus", base)  ])

		]).then(() => {

			let width  = window.innerWidth;
			let height = window.innerHeight;

			let game = new Game(avatar, wrapper, width, height);

			avatar.IsGameRunning = () => {
				return game.IsRunning();
			};

			avatar.OnGameStart = () => {
				game.Init();
				game.Start("level1");
			};

			wrapper.addEventListener("click", () => {

				setTimeout(() => {

					if (game.running === false) {

						game.avatar.Speak("me-want-cookies", () => {
							game.consent.Show();
						});

					}

				}, 3000);

			}, {
				once: true
			});

			wrapper.appendChild(game.consent.element);

			window.addEventListener("resize", () => {
				game.ResizeTo(window.innerWidth, window.innerHeight);
			});

			resolve(game);

		}).catch((err) => {
			reject(err);
		});

	});

};
