
import { EaseOut         } from "../math/EaseOut.mjs";
import { Palette         } from "../Palette.mjs";
import { vomit_buffer1   } from "./vomit_buffers.mjs";
import { vomit_buffer2   } from "./vomit_buffers.mjs";
import { vomit_particles } from "./vomit_particles.mjs";

export const DrawVomit = (position, feeling, statemap, time_delta) => {

	if (feeling === "vomit") {

		if (vomit_buffer1._hasvomit === false) {

			for (let p = 0, pl = vomit_particles.length; p < pl; p++) {

				let particle = vomit_particles[p];

				particle.x    = position.x;
				particle.y    = position.y;
				particle.size = 16 + Math.random() * 16;
				particle.blob = particle.size;
				particle.life = 500 + Math.random() * 250;

			}

			vomit_buffer1._hasvomit = true;

		}

	}

	let ctx1 = vomit_buffer1.getContext("2d");
	let ctx2 = vomit_buffer2.getContext("2d");
	let dt   = Date.now() - statemap["start"];

	if (dt < 250) {

		// Wait for actual throwup

	} else if (dt >= 250 && dt <= 750) {

		let t     = (dt - 250) / 500;
		let color = Palette["vomit"];

		ctx1.fillStyle = "rgba(" + color[0] + "," + color[1] + "," + color[2] + ",0.5)";

		for (let p = 0, pl = vomit_particles.length; p < pl; p++) {

			let particle = vomit_particles[p];
			if (particle.life > 0) {

				let f = EaseOut(t);

				particle.x    += Math.cos(particle.angle) * (1 - f) * 32 + Math.random() * 8 - Math.random() * 8;
				particle.y    += Math.sin(particle.angle) * (1 - f) * 32 + Math.random() * 8 - Math.random() * 8;
				particle.life -= time_delta;
				particle.size *= (1 - f);

				if (particle.size <= 0) {
					particle.life = 0;
				}

				ctx1.beginPath();
				ctx1.arc(
					particle.x,
					particle.y,
					particle.size,
					0,
					Math.PI * 2
				);
				ctx1.fill();
				ctx1.closePath();

			}

		}

		ctx2.clearRect(0, 0, vomit_buffer2.width, vomit_buffer2.height);
		ctx2.globalAlpha = 1;
		ctx2.drawImage(vomit_buffer1, 0, 0);

	} else if (dt > 750 && dt < 1500) {

		let t = (dt - 750) / 750;

		ctx2.clearRect(0, 0, vomit_buffer2.width, vomit_buffer2.height);
		ctx2.globalAlpha = 1 - t;
		ctx2.drawImage(vomit_buffer1, 0, 0);
		ctx2.globalAlpha = 1;

	}

};

