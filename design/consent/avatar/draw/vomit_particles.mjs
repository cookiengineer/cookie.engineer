
export const vomit_particles = new Array(360 / 10).fill(0).map((id, p) => ({
	id:    id,
	x:     0,
	y:     0,
	angle: p * 10,
	blob:  null,
	size:  null,
	life:  null
}));
