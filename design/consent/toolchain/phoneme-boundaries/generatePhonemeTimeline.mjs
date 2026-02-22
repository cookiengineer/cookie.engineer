import { detectPhonemeBoundaries } from "./detectPhonemeBoundaries.mjs";

export const generatePhonemeTimeline = (audioBuffer, config, phonemeMap, options = {}) => {
    // Detect candidate boundaries
    const boundaries = detectPhonemeBoundaries(audioBuffer, config, options);

    const timeline = config.timeline;
    const sentence = config.sentence;
    const result = [];

    const channelData = audioBuffer.getChannelData(0); // mono
    const sampleRate = audioBuffer.sampleRate;

    const frameSize = options.frameSize || 1024;
    const hopSize = options.hopSize || 512;

    // Hanning window
    const hanning = (n) => 0.5 - 0.5 * Math.cos((2 * Math.PI * n) / (frameSize - 1));

    // Helper functions
    const frameEnergy = (frame) => frame.reduce((sum, v) => sum + v * v, 0) / frame.length;
    const zeroCrossingRate = (frame) => {
        let zcr = 0;
        for (let i = 1; i < frame.length; i++) {
            if ((frame[i - 1] >= 0 && frame[i] < 0) || (frame[i - 1] < 0 && frame[i] >= 0)) zcr++;
        }
        return zcr / frame.length;
    };
    const fftReIm = (x) => {
        const N = x.length;
        if ((N & (N - 1)) !== 0) throw "FFT size must be power of 2";
        const rev = new Array(N);
        const nbits = Math.log2(N);
        for (let i = 0; i < N; i++) {
            let j = 0;
            for (let k = 0; k < nbits; k++) if ((i >> k) & 1) j |= 1 << (nbits - 1 - k);
            rev[i] = j;
        }
        const real = new Array(N);
        const imag = new Array(N).fill(0);
        for (let i = 0; i < N; i++) real[i] = x[rev[i]];

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

        const mag = new Array(N / 2);
        for (let i = 0; i < N / 2; i++) mag[i] = Math.sqrt(real[i] ** 2 + imag[i] ** 2);
        return mag;
    };
    const spectralCentroid = (mag) => {
        let num = 0, denom = 0;
        for (let k = 0; k < mag.length; k++) {
            num += k * mag[k];
            denom += mag[k];
        }
        if (denom === 0) return 0;
        return (num / denom) * (sampleRate / 2 / mag.length);
    };

    for (let w = 0; w < sentence.length; w++) {
        const word = sentence[w];
        const wordStart = timeline[w];
        const wordEnd = timeline[w + 1] || config.length;

        if (word === ".") {
            result.push({
                word: ".",
                start: wordStart,
                end: wordEnd,
                phonemes: [],
                features: []
            });
            continue;
        }

        const phonemes = phonemeMap[word] || [word];

        // Candidate boundaries
        const wordBoundaries = boundaries
            .filter(b => b > wordStart && b < wordEnd)
            .sort((a, b) => a - b);

        // Phoneme splitting
        const phonemeTimes = [];
        let phonemeStart = wordStart;
        if (wordBoundaries.length === 0) {
            const step = (wordEnd - wordStart) / phonemes.length;
            for (let i = 0; i < phonemes.length; i++) {
                phonemeTimes.push({
                    phoneme: phonemes[i],
                    start: Math.round(phonemeStart),
                    end: Math.round(phonemeStart + step)
                });
                phonemeStart += step;
            }
        } else {
            const allPoints = [wordStart, ...wordBoundaries, wordEnd];
            if (allPoints.length - 1 >= phonemes.length) {
                for (let i = 0; i < phonemes.length; i++) {
                    phonemeTimes.push({
                        phoneme: phonemes[i],
                        start: Math.round(allPoints[i]),
                        end: Math.round(allPoints[i + 1])
                    });
                }
            } else {
                const step = (wordEnd - wordStart) / phonemes.length;
                for (let i = 0; i < phonemes.length; i++) {
                    phonemeTimes.push({
                        phoneme: phonemes[i],
                        start: Math.round(wordStart + i * step),
                        end: Math.round(wordStart + (i + 1) * step)
                    });
                }
            }
        }

        // Frame-level features
        const features = [];
        const startSample = Math.floor((wordStart / 1000) * sampleRate);
        const endSample = Math.floor((wordEnd / 1000) * sampleRate);

        for (let i = startSample; i + frameSize <= endSample; i += hopSize) {
            const frame = channelData.slice(i, i + frameSize).map((v, idx) => v * hanning(idx));
            const t = (i / sampleRate) * 1000;

            features.push({
                time: t,
                energy: frameEnergy(frame),
                centroid: spectralCentroid(fftReIm(frame)),
                zcr: zeroCrossingRate(frame)
            });
        }

        result.push({
            word,
            start: wordStart,
            end: wordEnd,
            phonemes: phonemeTimes,
            features
        });
    }

    return result;
};
