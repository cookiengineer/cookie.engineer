
import { Init as InitAvatar } from "./avatar/Init.mjs";
import { Init as InitGame   } from "./game/Init.mjs";

(() => {

	let figure = document.querySelector("figure#avatar");

	InitAvatar(figure).then((avatar) => {

		InitGame(avatar, document.body).then((game) => {

			window.Refuse = () => {

				game.Init();
				game.UnlockSecret();

				if (game.IsFinished() === true) {
					game.Start("secret");
				} else {
					game.Start("level1");
				}

			};

		});

	});

})();

