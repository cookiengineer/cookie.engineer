
export const audio_context = new AudioContext();

(() => {

	document.addEventListener("click", () => {

		if (audio_context.state === "suspended") {

			try {
				audio_context.resume();
			} catch (_err) {
				// Do Nothing
			}

		}

	}, {
		once: true
	});

})();
