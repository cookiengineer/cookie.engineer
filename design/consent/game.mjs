
import { Init as InitAvatar } from "./avatar/Init.mjs";
import { Init as InitGame   } from "./game/Init.mjs";

(() => {

	let figure = document.querySelector("figure#avatar");

	InitAvatar(figure).then((avatar) => {

		InitGame(avatar, document.body).then((game) => {

			let query = window.location.search || "";
			if (query.includes("?debug") || query.includes("&debug")) {

				window.AVATAR = avatar;
				window.AVATAR.debug = true;

				window.GAME = game;
				window.GAME.debug = true;

			}

		});

	});

})();
