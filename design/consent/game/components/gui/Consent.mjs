
import { Avatar } from "../../../avatar/Avatar.mjs";
import { Game   } from "../../Game.mjs";

export const Consent = function(game, avatar) {

	game   = typeof game === "object"   && game instanceof Game     ? game   : null;
	avatar = typeof avatar === "object" && avatar instanceof Avatar ? avatar : null;

	this.game    = game;
	this.avatar  = avatar;
	this.element = document.createElement("div");
	this.element.setAttribute("id", "consent");
	this.element.innerHTML = [
		"<h3>We Value Your Privacy</h3>",
		"<p>",
		"By clicking \"Consent\" you agree that all Partners of the Galactic Cookie Empire have the right to store and/or access information on your device through the use of Cookies and similar technologies, and to process your personal data.",
		"<br/>",
		"<br/>",
		"Do you consent to sharing Cookies?",
		"</p>",
		"<div>",
		"<button data-action=\"consent\">Consent</button>",
		"&nbsp;",
		"<button data-action=\"manage\">Manage Options</button>",
		"</div>"
	].join("");

	this.element.querySelector("button[data-action=\"consent\"]").addEventListener("click", () => {

		this.element.className = "";

		if (this.game !== null && this.avatar !== null) {

			this.avatar.Speak("consent", () => {
				this.element.className = "active";
			});

		} else {

			setTimeout(() => {
				this.element.className = "active";
			}, 1000);

		}

	});

	this.element.querySelector("button[data-action=\"manage\"]").addEventListener("click", () => {

		this.element.className = "";

		if (this.game !== null && this.avatar !== null) {

			this.avatar.Speak("no-consent", () => {

				this.element.className = "";

				this.game.Init();
				this.game.Start("level1");

			});

		} else {

			setTimeout(() => {
				this.element.className = "";
			}, 500);

		}

	});

};

Consent.prototype = {

	Show: function() {
		this.element.className = "active";
	},

	Hide: function() {
		this.element.className = "";
	}

};
