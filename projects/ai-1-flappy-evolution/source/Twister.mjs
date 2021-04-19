
const UPPER_MASK = 0x80000000;
const LOWER_MASK = 0x7fffffff;
const XOR_MATRIX = new Array(0x0, 0x9908b0df);

const initialize = function(seed) {

	let index   = 1;
	let N       = this.N;
	let twister = this.twister;


	twister[0] = seed >>> 0;


	while (index < N) {

		let value = twister[index - 1] ^ (twister[index - 1] >>> 30);

		twister[index] = (((((value & 0xffff0000) >>> 16) * 1812433253) << 16) + (value & 0x0000ffff) * 1812433253) + index;
		twister[index] >>>= 0;

		index++;

	}

	this.index = index;

};

const random_int32 = function() {

	let index   = this.index;
	let twister = this.twister;
	let value   = 0;
	let M       = this.M;
	let N       = this.N;


	if (index >= N) {

		let i = 0;

		if (index === N + 1) {
			initialize.call(this, 5489);
		}


		while (i < N - M) {

			value      = (twister[i] & UPPER_MASK) | (twister[i + 1] & LOWER_MASK);
			twister[i] = twister[i + M] ^ (value >>> 1) ^ XOR_MATRIX[value & 0x1];

			i++;

		}

		while (i < N - 1) {

			value      = (twister[i] & UPPER_MASK) | (twister[i + 1] & LOWER_MASK);
			twister[i] = twister[i + (M - N)] ^ (value >>> 1) ^ XOR_MATRIX[value & 0x1];

			i++;

		}


		value          = (twister[N - 1] & UPPER_MASK) | (twister[0] & LOWER_MASK);
		twister[N - 1] = twister[M - 1] ^ (value >>> 1) ^ XOR_MATRIX[value & 0x1];

		this.index = 0;

	}


	value = twister[this.index++];

	value ^= (value >>> 11);
	value ^= (value  <<  7) & 0x9d2c5680;
	value ^= (value  << 15) & 0xefc60000;
	value ^= (value >>> 18);


	return value >>> 0;

};



const Twister = function(seed) {

	seed = typeof seed === 'number' ? (seed | 0) : ((Math.random() * Number.MAX_SAFE_INTEGER) | 0);


	this.N = 624;
	this.M = 397;

	this.twister = new Array(this.N);
	this.index   = this.N + 1;

	this.__seed  = seed;


	initialize.call(this, seed);

	seed = null;

};


Twister.prototype = {

	random: function() {

		return random_int32.call(this) * (1.0 / 4294967296.0);

	}

};



export { Twister };
