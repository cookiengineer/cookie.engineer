
import { GetImage } from "../../common/image/GetImage.mjs";

export const Explosion = function(x, y) {

	this.image = GetImage("Explosion");

	this.life      = 1.0;
	this.particles = [];

	let amount  = 10 + (Math.random() * 10);
	let maxlife = 0.0;

	for (let p = 0; p < amount; p++) {

		let angle = Math.random() * Math.PI * 2;
		let speed = 10 + Math.random() * 30;
		let life  = Math.random() * 1.0;

		if (life > maxlife) {
			maxlife = life;
		}

		this.particles.push({
			life: life,
			r:    (16 + Math.random() * 32) | 0,
			x:    x,
			y:    y,
			vx:   Math.cos(angle) * speed,
			vy:   Math.sin(angle) * speed
		});

	}

	this.life = maxlife;

};

Explosion.prototype = {

	Render: function(ctx, delta) {

		for (let p = 0, pl = this.particles.length; p < pl; p++) {

			let particle = this.particles[p];

			ctx.globalAlpha = (particle.life / 1.0);
			ctx.drawImage(
				this.image,
				0,
				0,
				64,
				64,
				particle.x - particle.r,
				particle.y - particle.r,
				particle.r * 2,
				particle.r * 2
			);
			ctx.globalAlpha = 1.0;

		}

	},

	Update: function(delta, width, height) {

		let dt = delta / 1000;

		for (let p = 0, pl = this.particles.length; p < pl; p++) {

			let particle = this.particles[p];

			particle.life = particle.life - dt;
			particle.x    = particle.x + (dt * particle.vx);
			particle.y    = particle.y + (dt * particle.vy);

			if (particle.life <= 0.0) {
				this.particles.splice(p, 1);
				pl--;
				p--;
			}

		}

	}

};
