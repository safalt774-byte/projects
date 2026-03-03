import 'dart:typed_data';
import 'dart:math' as math;

/// Pitch detection result with confidence and cents offset
class PitchResult {
  final int midiNote;
  final double frequency;
  final double confidence;
  final double centsOffset; // How many cents off from perfect pitch

  const PitchResult({
    required this.midiNote,
    required this.frequency,
    required this.confidence,
    required this.centsOffset,
  });
}

/// Client-side pitch detection optimized for guitar
/// Uses autocorrelation with human-ear-friendly tolerances
class PitchDetector {
  static const int sampleRate = 22050;
  static const double minFreq = 75.0;    // Below low E to catch slightly flat notes
  static const double maxFreq = 1400.0;  // Above high E to catch slightly sharp notes

  // ══ Human hearing tolerances ═══════════════════════════════
  // Professional musicians can hear ~5 cents difference
  // Average person can hear ~15-25 cents
  // Beginners should get ~50 cents tolerance (quarter semitone)

  static const double perfectTolerance = 15.0;    // cents - sounds perfect
  static const double goodTolerance = 35.0;       // cents - sounds good
  static const double acceptableTolerance = 50.0; // cents - acceptable for learning
  static const double closeEnoughTolerance = 80.0; // cents - recognizably the same note

  /// Detect pitch with detailed result
  /// Returns null if no clear pitch detected
  static PitchResult? detectPitchDetailed(Uint8List audioBytes) {
    if (audioBytes.length < 2048) return null;

    final samples = _bytesToFloatSamples(audioBytes);
    if (samples.length < 1024) return null;

    // Check signal level
    final rms = _calculateRMS(samples);
    if (rms < 0.008) return null; // Too quiet - ignore background noise

    // Detect frequency
    final result = _autocorrelationWithConfidence(samples);
    if (result == null) return null;

    final frequency = result.$1;
    final confidence = result.$2;

    if (frequency < minFreq || frequency > maxFreq) return null;
    if (confidence < 0.15) return null; // Not confident enough

    // Convert to MIDI with cents offset
    final exactMidi = _frequencyToMidi(frequency);
    final roundedMidi = exactMidi.round();
    final centsOffset = (exactMidi - roundedMidi) * 100; // Convert to cents

    return PitchResult(
      midiNote: roundedMidi,
      frequency: frequency,
      confidence: confidence,
      centsOffset: centsOffset,
    );
  }

  /// Simple detection - returns just MIDI note (backwards compatible)
  static int? detectPitch(Uint8List audioBytes) {
    final result = detectPitchDetailed(audioBytes);
    return result?.midiNote;
  }

  /// Check if detected note matches expected note within tolerance
  /// Returns match quality: 'perfect', 'good', 'acceptable', 'close', 'wrong'
  static String matchQuality(int detected, int expected, {double centsOffset = 0}) {
    final semitoneDiff = (detected - expected).abs();

    if (semitoneDiff == 0) {
      // Same note - check cents for quality
      final absCents = centsOffset.abs();
      if (absCents <= perfectTolerance) return 'perfect';
      if (absCents <= goodTolerance) return 'good';
      if (absCents <= acceptableTolerance) return 'acceptable';
      return 'acceptable'; // Same note is always at least acceptable
    }

    if (semitoneDiff == 1) {
      // One semitone off - might still sound close enough
      // If they're sharp/flat in the right direction, count as close
      return 'close';
    }

    if (semitoneDiff == 2) {
      // Two semitones - definitely wrong but recognizable attempt
      return 'close';
    }

    return 'wrong';
  }

  /// Check if note is "correct enough" for a beginner
  static bool isCorrectForBeginner(int detected, int expected) {
    final quality = matchQuality(detected, expected);
    return quality == 'perfect' ||
        quality == 'good' ||
        quality == 'acceptable' ||
        quality == 'close';
  }

  /// Check if note is correct for advancing (stricter than beginner)
  static bool isCorrectForAdvance(int detected, int expected) {
    final quality = matchQuality(detected, expected);
    return quality == 'perfect' ||
        quality == 'good' ||
        quality == 'acceptable';
  }

  // ── Internal methods ───────────────────────────────────────

  static List<double> _bytesToFloatSamples(Uint8List bytes) {
    final samples = <double>[];

    for (int i = 0; i < bytes.length - 1; i += 2) {
      int sample = bytes[i] | (bytes[i + 1] << 8);
      if (sample > 32767) sample = sample - 65536;
      samples.add(sample / 32768.0);
    }

    return samples;
  }

  static double _calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double sum = 0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    return math.sqrt(sum / samples.length);
  }

  static (double, double)? _autocorrelationWithConfidence(List<double> samples) {
    final int size = samples.length;
    final int minLag = (sampleRate / maxFreq).floor();
    final int maxLagValue = (sampleRate / minFreq).ceil();
    final int searchMaxLag = math.min(maxLagValue, size ~/ 2);

    if (minLag >= searchMaxLag) return null;

    double maxCorrelation = 0;
    int bestLag = 0;
    double totalEnergy = 0;

    // Calculate total energy for normalization
    for (final s in samples) {
      totalEnergy += s * s;
    }
    if (totalEnergy < 0.001) return null;

    for (int lag = minLag; lag < searchMaxLag; lag++) {
      double correlation = 0;

      for (int i = 0; i < size - lag; i++) {
        correlation += samples[i] * samples[i + lag];
      }

      // Normalize
      correlation = correlation / totalEnergy;

      if (correlation > maxCorrelation) {
        maxCorrelation = correlation;
        bestLag = lag;
      }
    }

    if (bestLag == 0) return null;

    final frequency = sampleRate / bestLag;
    return (frequency, maxCorrelation);
  }

  static double _frequencyToMidi(double frequency) {
    return 69 + 12 * (math.log(frequency / 440.0) / math.ln2);
  }

  static double midiToFrequency(int midiNote) {
    return 440.0 * math.pow(2, (midiNote - 69) / 12.0);
  }

  static String midiToNoteName(int midi) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final octave = (midi ~/ 12) - 1;
    final note = notes[midi % 12];
    return '$note$octave';
  }
}