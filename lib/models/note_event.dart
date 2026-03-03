/// Matches exactly what your FastAPI returns:
/// { "pitch": 64, "start": 0.0, "duration": 1.0 }
///
/// Also stores the mapped guitar position (string + fret)
/// which is computed by MidiMapper after receiving the API response.
class NoteEvent {
  final int pitch;          // raw MIDI number from API
  final double startMs;     // converted from seconds → milliseconds
  final double durationMs;  // converted from seconds → milliseconds
  final int stringIndex;    // 0=high e, 1=B, 2=G, 3=D, 4=A, 5=low E
  final int fret;           // 0=open string, 1-16=fret number

  const NoteEvent({
    required this.pitch,
    required this.startMs,
    required this.durationMs,
    required this.stringIndex,
    required this.fret,
  });

  /// Build from the raw JSON map that FastAPI sends.
  /// api.py returns: { "pitch": int, "start": double, "duration": double }
  /// MidiMapper provides the stringIndex and fret.
  factory NoteEvent.fromJson(
      Map<String, dynamic> json, {
        required int stringIndex,
        required int fret,
      }) {
    return NoteEvent(
      pitch: json['pitch'] as int,
      // API gives seconds, we need milliseconds for animation
      startMs: (json['start'] as num).toDouble() * 1000,
      durationMs: (json['duration'] as num).toDouble() * 1000,
      stringIndex: stringIndex,
      fret: fret,
    );
  }
}