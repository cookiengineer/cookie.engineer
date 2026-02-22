
import { detectPhonemeBoundaries } from "./detectPhonemeBoundaries.mjs";

export const generatePhonemeTimings = (audioBuffer, config, phonemeMap, options = {}) => {
    // 1. Detect candidate boundaries
    const boundaries = detectPhonemeBoundaries(audioBuffer, config, options);

    const result = {};
    const timeline = config.timeline;
    const sentence = config.sentence;

    for (let w = 0; w < sentence.length; w++) {
        const word = sentence[w];
        if (word === ".") continue; // skip intentional breaks

        const phonemes = phonemeMap[word] || [word]; // fallback: treat word as single phoneme
        const wordStart = timeline[w];
        const wordEnd = timeline[w + 1] || config.length;

        // Get candidate boundaries inside this word
        const wordBoundaries = boundaries
            .filter(b => b > wordStart && b < wordEnd)
            .sort((a, b) => a - b);

        const phonemeTimes = [];
        let phonemeStart = wordStart;

        if (wordBoundaries.length === 0) {
            // No boundaries detected: split evenly
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
            // Boundaries exist: split phonemes between them
            const allPoints = [wordStart, ...wordBoundaries, wordEnd];
            if (allPoints.length - 1 >= phonemes.length) {
                // Assign each phoneme to a boundary segment
                for (let i = 0; i < phonemes.length; i++) {
                    phonemeTimes.push({
                        phoneme: phonemes[i],
                        start: Math.round(allPoints[i]),
                        end: Math.round(allPoints[i + 1])
                    });
                }
            } else {
                // Fewer segments than phonemes: interpolate
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

        result[word] = phonemeTimes;
    }

    return result;
}
