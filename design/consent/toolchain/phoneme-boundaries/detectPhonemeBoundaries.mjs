
export const detectPhonemeBoundaries = (audioBuffer, config, options = {}) => {
	const channelData = audioBuffer.getChannelData(0); // mono
	const sampleRate = audioBuffer.sampleRate;

	// Configurable parameters
	const frameSize = options.frameSize || 1024;
	const hopSize = options.hopSize || 512;
	const energyThreshold = options.energyThreshold || 0.02;
	const centroidThreshold = options.centroidThreshold || 1000; // Hz
	const zcrThreshold = options.zcrThreshold || 0.05;
	const smoothingFrames = options.smoothingFrames || 2;

	// Hanning window
	function hanning(n) {
		return 0.5 - 0.5 * Math.cos((2 * Math.PI * n) / (frameSize - 1));
	}

	// Compute frame energy
	function frameEnergy(frame) {
		let sum = 0;
		for (let i = 0; i < frame.length; i++) sum += frame[i] * frame[i];
		return sum / frame.length;
	}

	// Zero-crossing rate
	function zeroCrossingRate(frame) {
		let zcr = 0;
		for (let i = 1; i < frame.length; i++) {
			if ((frame[i - 1] >= 0 && frame[i] < 0) || (frame[i - 1] < 0 && frame[i] >= 0)) zcr++;
		}
		return zcr / frame.length;
	}

	// In-place Cooley-Tukey FFT (radix-2)
	function fftReIm(x) {
		const N = x.length;
		if ((N & (N - 1)) !== 0) throw "FFT size must be power of 2";

		// Bit-reversal permutation
		const rev = new Array(N);
		let nbits = Math.log2(N);
		for (let i = 0; i < N; i++) {
			let j = 0;
			for (let k = 0; k < nbits; k++) if ((i >> k) & 1) j |= 1 << (nbits - 1 - k);
			rev[i] = j;
		}

		const real = new Array(N);
		const imag = new Array(N).fill(0);
		for (let i = 0; i < N; i++) real[i] = x[rev[i]];

		// FFT
		for (let s = 1; s <= nbits; s++) {
			const m = 1 << s;
			const m2 = m / 2;
			const theta = -2 * Math.PI / m;
			const wRe = Math.cos(theta);
			const wIm = Math.sin(theta);

			for (let k = 0; k < N; k += m) {
				let wr = 1, wi = 0;
				for (let j = 0; j < m2; j++) {
					const tRe = wr * real[k + j + m2] - wi * imag[k + j + m2];
					const tIm = wr * imag[k + j + m2] + wi * real[k + j + m2];
					real[k + j + m2] = real[k + j] - tRe;
					imag[k + j + m2] = imag[k + j] - tIm;
					real[k + j] += tRe;
					imag[k + j] += tIm;

					const tmpWr = wr;
					wr = wr * wRe - wi * wIm;
					wi = tmpWr * wIm + wi * wRe;
				}
			}
		}

		// Compute magnitude
		const mag = new Array(N / 2);
		for (let i = 0; i < N / 2; i++) mag[i] = Math.sqrt(real[i] ** 2 + imag[i] ** 2);
		return mag;
	}

	// Spectral centroid
	function spectralCentroid(mag) {
		let num = 0, denom = 0;
		for (let k = 0; k < mag.length; k++) {
			num += k * mag[k];
			denom += mag[k];
		}
		if (denom === 0) return 0;
		return (num / denom) * (sampleRate / 2 / mag.length);
	}

	// Smooth features
	function smooth(arr, n = 2) {
		const result = [];
		for (let i = 0; i < arr.length; i++) {
			let sum = 0, count = 0;
			for (let j = -n; j <= n; j++) {
				if (i + j >= 0 && i + j < arr.length) {
					sum += arr[i + j];
					count++;
				}
			}
			result.push(sum / count);
		}
		return result;
	}

	// Frame processing
	const energies = [];
	const centroids = [];
	const zcrs = [];

	for (let i = 0; i + frameSize <= channelData.length; i += hopSize) {
		const frame = channelData.slice(i, i + frameSize).map((v, idx) => v * hanning(idx));
		energies.push(frameEnergy(frame));
		zcrs.push(zeroCrossingRate(frame));
		const mag = fftReIm(frame);
		centroids.push(spectralCentroid(mag));
	}

	const smoothEnergies = smooth(energies, smoothingFrames);
	const smoothCentroids = smooth(centroids, smoothingFrames);
	const smoothZCRs = smooth(zcrs, smoothingFrames);

	// Detect boundaries
	const boundaries = [];
	for (let i = 1; i < smoothEnergies.length; i++) {
		const eDiff = Math.abs(smoothEnergies[i] - smoothEnergies[i - 1]);
		const cDiff = Math.abs(smoothCentroids[i] - smoothCentroids[i - 1]);
		const zDiff = Math.abs(smoothZCRs[i] - smoothZCRs[i - 1]);

		if (eDiff > energyThreshold || cDiff > centroidThreshold || zDiff > zcrThreshold) {
			boundaries.push((i * hopSize / sampleRate) * 1000); // ms
		}
	}

	return boundaries.filter(b => b >= config.timeline[0] && b <= config.timeline[config.timeline.length - 1]);
}
