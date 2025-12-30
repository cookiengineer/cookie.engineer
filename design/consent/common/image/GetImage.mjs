
import { image_buffers } from "./image_buffers.mjs";

export const GetImage = (name) => {

	let image = image_buffers[name] || null;
	if (image !== null) {
		return image;
	}

	return null;

};
