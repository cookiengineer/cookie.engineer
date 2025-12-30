
import { playing } from "./playing.mjs";

export const IsPlaying = () => {
	return playing.buffersource !== null;
};
