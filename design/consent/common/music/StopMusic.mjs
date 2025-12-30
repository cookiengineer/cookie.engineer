
import { playing } from "./playing.mjs";

export const StopMusic = () => {

	if (playing.buffersource !== null) {

		try {
			playing.buffersource.stop();
		} catch(_err) {
			// Do Nothing
		}

		playing.buffersource.disconnect();
		playing.buffersource = null;

	}

};
