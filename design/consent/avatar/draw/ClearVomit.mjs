
import { vomit_buffer1, vomit_buffer2 } from "./vomit_buffers.mjs";

export const ClearVomit = () => {

	if (vomit_buffer1._hasvomit === true) {

		let ctx_buffer1 = vomit_buffer1.getContext("2d");
		let ctx_buffer2 = vomit_buffer2.getContext("2d");

		ctx_buffer1.clearRect(0, 0, vomit_buffer1.width, vomit_buffer1.height);
		ctx_buffer2.clearRect(0, 0, vomit_buffer2.width, vomit_buffer2.height);

		vomit_buffer1._hasvomit = false;

	}

};

