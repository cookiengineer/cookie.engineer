
import { Init as InitAvatar } from "./avatar/Init.mjs";
import { Init as InitGame   } from "./game/Init.mjs";

(() => {

	let button_level1 = document.querySelector("button[data-action=\"start-level1\"]");
	let button_level2 = document.querySelector("button[data-action=\"start-level2\"]");
	let button_level3 = document.querySelector("button[data-action=\"start-level3\"]");
	let button_secret = document.querySelector("button[data-action=\"start-secret\"]");
	let start_resized = Array.from(document.querySelectorAll("button[data-action=\"start-resized\"]"));
	let figure        = document.querySelector("figure#avatar");

	InitAvatar(figure).then((avatar) => {

		InitGame(avatar, document.body).then((game) => {

			let query = window.location.search || "";
			if (query.includes("?debug") || query.includes("&debug")) {

				window.AVATAR = avatar;
				window.AVATAR.debug = true;

				window.GAME = game;
				window.GAME.debug = true;

			}

			button_level1.addEventListener("click", () => {

				game.Init();
				game.Start("level1");

			});

			button_level2.addEventListener("click", () => {

				game.Init();

				game.statistics["level1"] = {
					missed:   0,
					killed:  78,
					spawned: 78
				};

				game.Start("level2");

			});

			button_level3.addEventListener("click", () => {

				game.Init();

				game.statistics["level1"] = {
					missed:   0,
					killed:  78,
					spawned: 78
				};
				game.statistics["level2"] = {
					missed:   0,
					killed:  86,
					spawned: 86
				};

				game.Start("level3");

			});

			button_secret.addEventListener("click", () => {

				game.Init();
				game.UnlockSecret();

				game.statistics["level1"] = {
					missed:   0,
					killed:  78,
					spawned: 78
				};
				game.statistics["level2"] = {
					missed:   0,
					killed:  86,
					spawned: 86
				};
				game.statistics["level3"] = {
					missed:   0,
					killed:  17,
					spawned: 17
				};

				game.Start("secret");

			});

			start_resized.forEach((button) => {

				button.addEventListener("click", () => {

					let resolution = button.getAttribute("data-resolution");
					if (resolution !== null) {

						let width  = Number.parseInt(resolution.split("x").shift(), 10);
						let height = Number.parseInt(resolution.split("x").pop(), 10);

						if (Number.isNaN(width) === false && Number.isNaN(height) === false) {

							game.Init();

							game.ResizeTo(width, height);

							game.Start("level1");

						}

					}

				});


			});


		});

	});

})();
