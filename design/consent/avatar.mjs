
import { Init as InitAvatar } from "./avatar/Init.mjs";

(() => {

	let figure = document.querySelector("figure#avatar");

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

	});

})();
