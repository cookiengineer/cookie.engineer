export const vomit_buffer1 = document.createElement("canvas");
export const vomit_buffer2 = document.createElement("canvas");

(() => {

	vomit_buffer1._hasvomit = false;
	vomit_buffer1.width = window.innerWidth;
	vomit_buffer1.height = window.innerHeight;

	vomit_buffer2.width = window.innerWidth;
	vomit_buffer2.height = window.innerHeight;

	vomit_buffer2.style["display"]        = "block";
	vomit_buffer2.style["position"]       = "fixed";
	vomit_buffer2.style["width"]          = window.innerWidth  + "px";
	vomit_buffer2.style["height"]         = window.innerHeight + "px";
	vomit_buffer2.style["zIndex"]         = 100;
	vomit_buffer2.style["top"]            = "0px";
	vomit_buffer2.style["right"]          = "0px";
	vomit_buffer2.style["bottom"]         = "0px";
	vomit_buffer2.style["left"]           = "0px";
	vomit_buffer2.style["pointer-events"] = "none";
	vomit_buffer2.style["touch-action"]   = "none";
	vomit_buffer2.style["user-select"]    = "none";

	let body = document.querySelector("body");
	if (body !== null) {
		body.appendChild(vomit_buffer2);
	}

	window.addEventListener("resize", () => {

		vomit_buffer1.width = window.innerWidth;
		vomit_buffer1.height = window.innerHeight;

		vomit_buffer2.width = window.innerWidth;
		vomit_buffer2.height = window.innerHeight;

		vomit_buffer2.style["width"]  = window.innerWidth  + "px";
		vomit_buffer2.style["height"] = window.innerHeight + "px";

	}, true);

})();
