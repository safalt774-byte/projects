import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// Centralized sound-effects & haptic-feedback service.
/// Generates simple tones in-memory (no asset files needed).
class AppFeedbackService {
  AppFeedbackService._();
  static final instance = AppFeedbackService._();

  bool _disposed = false;

  void dispose() {
    _disposed = true;
  }

  // ── Haptics ────────────────────────────────────────────────

  static void hapticLight()  => HapticFeedback.lightImpact();
  static void hapticMedium() => HapticFeedback.mediumImpact();
  static void hapticHeavy()  => HapticFeedback.heavyImpact();
  static void hapticTick()   => HapticFeedback.selectionClick();

  // ── Sound Effects ──────────────────────────────────────────

  /// Soft click for button taps
  Future<void> playTick() async {
    hapticTick();
    await _playTone(freq: 800, durationMs: 30, volume: 0.15);
  }

  /// Rising tone for correct note
  Future<void> playSuccess() async {
    hapticMedium();
    await _playTone(freq: 880, durationMs: 80, volume: 0.2);
  }

  /// Perfect hit — bright chirp
  Future<void> playPerfect() async {
    hapticMedium();
    await _playTone(freq: 1320, durationMs: 100, volume: 0.25);
  }

  /// Dull buzz for wrong note
  Future<void> playError() async {
    hapticHeavy();
    await _playTone(freq: 220, durationMs: 120, volume: 0.2);
  }

  /// Short whoosh-like sweep for page transitions
  Future<void> playWhoosh() async {
    hapticLight();
    await _playSweep(fromFreq: 600, toFreq: 300, durationMs: 100, volume: 0.12);
  }

  /// Countdown beep
  Future<void> playCountdownBeep({bool isFinal = false}) async {
    hapticHeavy();
    await _playTone(
      freq: isFinal ? 1046 : 523,
      durationMs: isFinal ? 200 : 100,
      volume: 0.3,
    );
  }

  /// Streak chime — ascending arpeggio
  Future<void> playStreakChime() async {
    hapticHeavy();
    await _playTone(freq: 1047, durationMs: 60, volume: 0.2);
    await Future.delayed(const Duration(milliseconds: 70));
    await _playTone(freq: 1319, durationMs: 60, volume: 0.2);
    await Future.delayed(const Duration(milliseconds: 70));
    await _playTone(freq: 1568, durationMs: 100, volume: 0.25);
  }

  /// Completion fanfare
  Future<void> playCompletionFanfare() async {
    hapticHeavy();
    final notes = [523, 659, 784, 1047];
    for (int i = 0; i < notes.length; i++) {
      await _playTone(freq: notes[i].toDouble(), durationMs: 120, volume: 0.25);
      await Future.delayed(const Duration(milliseconds: 130));
    }
  }

  // ── Tone Generation ────────────────────────────────────────

  Future<void> _playTone({
    required double freq,
    required int durationMs,
    double volume = 0.2,
  }) async {
    if (_disposed) return;
    try {
      final wav = _generateWav(freq, durationMs, volume);
      final player = AudioPlayer();
      await player.setSourceBytes(wav);
      await player.resume();
      Future.delayed(Duration(milliseconds: durationMs + 200), () {
        try { player.dispose(); } catch (_) {}
      });
    } catch (_) {}
  }

  Future<void> _playSweep({
    required double fromFreq,
    required double toFreq,
    required int durationMs,
    double volume = 0.15,
  }) async {
    if (_disposed) return;
    try {
      final wav = _generateSweepWav(fromFreq, toFreq, durationMs, volume);
      final player = AudioPlayer();
      await player.setSourceBytes(wav);
      await player.resume();
      Future.delayed(Duration(milliseconds: durationMs + 200), () {
        try { player.dispose(); } catch (_) {}
      });
    } catch (_) {}
  }

  /// Generate a simple sine-wave WAV in memory.
  Uint8List _generateWav(double freq, int durationMs, double volume) {
    const sampleRate = 22050;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final pcm = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double envelope = 1.0;
      const fadeMs = 5;
      final fadeSamples = (sampleRate * fadeMs / 1000).round();
      if (i < fadeSamples) {
        envelope = i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        envelope = (numSamples - i) / fadeSamples;
      }
      pcm[i] = (sin(2 * pi * freq * t) * volume * envelope * 32767).round().clamp(-32768, 32767);
    }

    return _pcmToWav(pcm, sampleRate);
  }

  /// Generate a frequency sweep WAV.
  Uint8List _generateSweepWav(double fromFreq, double toFreq, int durationMs, double volume) {
    const sampleRate = 22050;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final pcm = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final progress = i / numSamples;
      final freq = fromFreq + (toFreq - fromFreq) * progress;

      double envelope = 1.0;
      const fadeMs = 5;
      final fadeSamples = (sampleRate * fadeMs / 1000).round();
      if (i < fadeSamples) {
        envelope = i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        envelope = (numSamples - i) / fadeSamples;
      }
      pcm[i] = (sin(2 * pi * freq * t) * volume * envelope * 32767).round().clamp(-32768, 32767);
    }

    return _pcmToWav(pcm, sampleRate);
  }

  /// Wrap raw 16-bit PCM into a valid WAV byte buffer.
  Uint8List _pcmToWav(Int16List pcm, int sampleRate) {
    final dataSize = pcm.length * 2;
    final fileSize = 36 + dataSize;
    final buffer = ByteData(44 + dataSize);

    // RIFF header
    buffer.setUint8(0, 0x52); buffer.setUint8(1, 0x49);
    buffer.setUint8(2, 0x46); buffer.setUint8(3, 0x46);
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57); buffer.setUint8(9, 0x41);
    buffer.setUint8(10, 0x56); buffer.setUint8(11, 0x45);

    // fmt chunk
    buffer.setUint8(12, 0x66); buffer.setUint8(13, 0x6D);
    buffer.setUint8(14, 0x74); buffer.setUint8(15, 0x20);
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, 1, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);

    // data chunk
    buffer.setUint8(36, 0x64); buffer.setUint8(37, 0x61);
    buffer.setUint8(38, 0x74); buffer.setUint8(39, 0x61);
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < pcm.length; i++) {
      buffer.setInt16(44 + i * 2, pcm[i], Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}

