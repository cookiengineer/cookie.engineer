
import { image_buffers } from "./image_buffers.mjs";

export const LoadImage = (name, url) => {

	let check = image_buffers[name] || null;
	if (check !== null) {

		return new Promise((resolve, reject) => {
			resolve(image_buffers[name]);
		});

	} else {

		return new Promise((resolve, reject) => {

			let img = new Image();

			img.onload = () => {

				image_buffers[name] = img;
				resolve(img);

			};

			img.onerror = (err) => {
				reject(err);
			};

			img.src = url;

		});

	}

};
