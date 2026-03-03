/// Converts a MIDI pitch number into a guitar string + fret position.
/// Uses standard guitar position playing — spreads notes naturally
/// across all 6 strings instead of cramming everything onto string 0.
class MidiMapper {
  // Standard tuning open string MIDI numbers
  static const List<int> _openStrings = [64, 59, 55, 50, 45, 40];
  // index:                               0    1    2    3    4    5
  //                                      e    B    G    D    A    E

  static const int _maxFret = 12; // keep in beginner range

  /// Returns (stringIndex, fret) for a given MIDI pitch.
  ///
  /// Strategy — "standard position" playing:
  ///   • Notes above MIDI 64  (E4)  → strings 0–1  (e, B)
  ///   • Notes MIDI 55–64     (G3–E4) → strings 1–2  (B, G)
  ///   • Notes MIDI 50–55     (D3–G3) → strings 2–3  (G, D)
  ///   • Notes MIDI 45–50     (A2–D3) → strings 3–4  (D, A)
  ///   • Notes below MIDI 45         → strings 4–5  (A, E)
  ///
  /// Within each region the LOWEST fret is picked.
  /// Returns null if the note is outside guitar range.
  static (int, int)? toStringFret(int midiPitch) {
    if (midiPitch < 40 || midiPitch > 88) return null;

    // Determine which strings to prefer based on pitch region
    final List<int> preferredStrings;
    if (midiPitch >= 64) {
      preferredStrings = [0, 1];        // high e, B
    } else if (midiPitch >= 55) {
      preferredStrings = [1, 2, 0];     // B, G, high e
    } else if (midiPitch >= 50) {
      preferredStrings = [2, 3, 1];     // G, D, B
    } else if (midiPitch >= 45) {
      preferredStrings = [3, 4, 2];     // D, A, G
    } else {
      preferredStrings = [4, 5, 3];     // A, low E, D
    }

    // Within preferred strings, pick the one with lowest fret
    int bestString = -1;
    int bestFret   = 999;

    for (final s in preferredStrings) {
      final fret = midiPitch - _openStrings[s];
      if (fret >= 0 && fret <= _maxFret && fret < bestFret) {
        bestFret   = fret;
        bestString = s;
      }
    }

    // Fallback: try all strings if preferred gave nothing
    if (bestString == -1) {
      for (int s = 0; s < _openStrings.length; s++) {
        final fret = midiPitch - _openStrings[s];
        if (fret >= 0 && fret <= _maxFret && fret < bestFret) {
          bestFret   = fret;
          bestString = s;
        }
      }
    }

    if (bestString == -1) return null;
    return (bestString, bestFret);
  }
}