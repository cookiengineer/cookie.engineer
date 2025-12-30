
const search = (key, val) => {

	let results = Array.from(document.querySelectorAll("dd[data-key=\"" + key + "\"]")).filter((element) => {
		return element.getAttribute("data-val") === val;
	});

	let articles = Array.from(document.querySelectorAll("section.timeline > article"));
	if (articles.length > 0) {
		articles.forEach((article) => {

			if (article.getAttribute("id") !== "search") {
				article.setAttribute("data-result", "false");
			}

		});
	}

	if (results.length > 0) {

		results.forEach((element) => {

			let parent = element.parentNode;

			while (parent !== document.body && parent.tagName !== "ARTICLE") {
				parent = parent.parentNode;
			}

			if (parent.tagName === "ARTICLE" && parent.getAttribute("id") !== "search") {
				parent.setAttribute("data-result", "true");
			}

		});

	}

};

window.addEventListener("hashchange", () => {

	let hash = window.location.hash || "";
	if (hash.startsWith("#?tag=")) {
		search("tag", hash.substr(6));
	}

}, true);

(() => {

	let hash = window.location.hash || "";
	if (hash.startsWith("#?tag=")) {
		search("tag", hash.substr(6));
	}

})();

