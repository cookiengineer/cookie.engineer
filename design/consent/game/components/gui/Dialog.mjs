
import { IsPlaying } from "../../../common/music/IsPlaying.mjs";
import { StopMusic } from "../../../common/music/StopMusic.mjs";

const ranks = (() => {

	const base = new URL(".", import.meta.url);

	return {
		"level1": {
			"title": "First Cookie Order Cadet",
			"image": new URL("./DialogRank1.png", base)
		},
		"level2": {
			"title": "Cookie Rebel Alliance Commander",
			"image": new URL("./DialogRank2.png", base)
		},
		"level3": {
			"title": "Cookie Destroyer Destroyer",
			"image": new URL("./DialogRank3.png", base)
		},
		"secret": {
			"title": "Cookie Doxxing Brigade",
			"image": new URL("./DialogRankSecret.png", base)
		}
	};

})();

export const Dialog = function(game) {

	this.element = document.createElement("dialog");
	this.element.setAttribute("id", "game-over");
	this.element.innerHTML = [
		"<article>",
		"\t<h3>Your Rank: <span data-name=\"rank-title\">Cheater</span></h3>",
		"\t<img data-name=\"rank-image\" src=\"/design/consent/game/components/gui/DialogRank1.png\"/>",
		"\t<ul>",
		"\t\t<li><b>Level 1:</b> Destroyed <span data-name=\"level1-enemies-killed\">0</span> of <span data-name=\"level1-enemies-spawned\">0</span> cookies (<span data-name=\"level1-percentage\">0%</span>)</li>",
		"\t\t<li><b>Level 2:</b> Destroyed <span data-name=\"level2-enemies-killed\">0</span> of <span data-name=\"level2-enemies-spawned\">0</span> cookies (<span data-name=\"level2-percentage\">0%</span>)</li>",
		"\t\t<li><b>Level 3:</b> Destroyed <span data-name=\"level3-enemies-killed\">0</span> of <span data-name=\"level3-enemies-spawned\">0</span> cookies (<span data-name=\"level3-percentage\">0%</span>)</li>",
		"\t</ul>",
		"\t<footer>",
		"\t\t<div><button data-action=\"cancel\">Pull out! Retreat to Base!</button></div>",
		"\t\t<div></div>",
		"\t\t<div><button data-action=\"confirm\">Give it another shot, Rebel?</button></div>",
		"\t</footer>",
		"</article>"
	].join("");

	this.element.querySelector("button[data-action=\"confirm\"]").addEventListener("click", () => {

		let label = this.element.querySelector("button[data-action=\"confirm\"]").innerHTML;

		if (label === "Long live the Rebellion!") {

			if (IsPlaying() === true) {
				StopMusic();
			}

			game.Destroy();
			game.avatar.Speak("game-over", () => {
				game.avatar.Feel("okay");
			});

			this.Hide();

		} else {

			if (game.level === game.levels.level1) {
				game.Start("level1");
			} else if (game.level === game.levels.level2) {
				game.Start("level2");
			} else if (game.level === game.levels.level3) {
				game.Start("level3");
			} else if (game.level === game.levels.secret) {
				game.Start("secret");
			}

			this.Hide();

		}

	});

	this.element.querySelector("button[data-action=\"cancel\"]").addEventListener("click", () => {

		if (IsPlaying() === true) {
			StopMusic();
		}

		game.Destroy();
		game.avatar.Speak("game-over", () => {
			game.avatar.Feel("okay");
		});

		this.Hide();

	});

};

Dialog.prototype = {

	Show: function(statistics) {

		let rank = ranks["level1"];

		// ex gratia
		let level1_5_percent = (statistics.level1.spawned * 0.05);
		let level2_3_percent = (statistics.level2.spawned * 0.03);
		let level3_1_percent = (statistics.level3.spawned * 0.01);

		if (statistics.level1.killed > 0 && statistics.level1.killed >= (statistics.level1.spawned - level1_5_percent)) {

			rank = ranks["level1"];

			if (statistics.level2.killed > 0 && statistics.level2.killed >= (statistics.level2.spawned - level2_3_percent)) {

				rank = ranks["level2"];

				if (statistics.level3.killed > 0 && statistics.level3.killed >= (statistics.level3.killed - level3_1_percent)) {
					rank = ranks["level3"];
				}

			}

		}

		if (statistics.secret !== undefined) {
			rank = ranks["secret"];
		}

		let rank_title = this.element.querySelector("[data-name=\"rank-title\"]");
		let rank_image = this.element.querySelector("[data-name=\"rank-image\"]");

		rank_title.innerHTML = rank["title"];
		rank_image.src       = rank["image"].toString();

		[ "level1", "level2", "level3" ].forEach((level) => {

			let enemies_killed  = this.element.querySelector("[data-name=\"" + level + "-enemies-killed\"]");
			let enemies_spawned = this.element.querySelector("[data-name=\"" + level + "-enemies-spawned\"]");
			let percentage      = this.element.querySelector("[data-name=\"" + level + "-percentage\"]");

			let stats = statistics[level] || null;
			if (stats !== null && stats.killed > 0 && stats.spawned > 0) {
				enemies_killed.innerHTML  = (stats.killed).toString();
				enemies_spawned.innerHTML = (stats.spawned).toString();
				percentage.innerHTML      = (stats.killed / stats.spawned * 100.0).toFixed(2) + "%";
			} else {
				enemies_killed.innerHTML  = (stats.killed).toString();
				enemies_spawned.innerHTML = (stats.spawned).toString();
				percentage.innerHTML = "0.00%";
			}

		});

		let ul = this.element.querySelector("article ul");
		if (ul !== null && statistics.secret !== undefined) {

			let percentage = (statistics.secret.killed / statistics.secret.spawned * 100.0).toFixed(2) + "%";
			let li = ul.querySelector("li[data-secret=\"secret\"]");
			if (li !== null) {
				li.innerHTML = "<b>Secret:</b> Destroyed <span>" + (statistics.secret.killed).toString() + "</span> of <span>" + (statistics.secret.spawned).toString() + "</span> cookies (<span>" + percentage + "</span>)";
			} else {
				li = document.createElement("li");
				li.setAttribute("data-secret", "secret");
				li.innerHTML = "<b>Secret:</b> Destroyed <span>" + (statistics.secret.killed).toString() + "</span> of <span>" + (statistics.secret.spawned).toString() + "</span> cookies (<span>" + percentage + "</span>)";
				ul.appendChild(li);
			}

		}

		let button = this.element.querySelector("[data-action=\"confirm\"]");

		let stats_level1 = (statistics.level1.killed / statistics.level1.spawned * 100.0);
		let stats_level2 = (statistics.level2.killed / statistics.level2.spawned * 100.0);
		let stats_level3 = (statistics.level3.killed / statistics.level3.spawned * 100.0);

		if (stats_level1 >= 99.9 && stats_level2 >= 99.9 && stats_level3 >= 99.9) {
			button.innerHTML = "Long live the Rebellion!";
		} else {
			button.innerHTML = "Give it another shot, Rebel?";
		}

		this.element.setAttribute("open", "");
		document.body.appendChild(this.element);

	},

	Hide: function() {

		if (this.element.parentNode !== null) {
			this.element.removeAttribute("open");
			this.element.parentNode.removeChild(this.element);
		}

	}

};

