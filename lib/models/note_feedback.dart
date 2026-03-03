import 'package:flutter/material.dart';

enum FeedbackType {
  waiting,
  listening,
  perfect,
  good,
  acceptable,
  close,
  tooLow,
  tooHigh,
  wrong,
}

/// Smart feedback with encouraging messages
class NoteFeedback {
  final FeedbackType type;
  final String message;
  final String? hint;
  final Color color;
  final bool shouldAdvance; // Should we move to next note?
  final bool shouldRetry;   // Should we retry this note?

  const NoteFeedback({
    required this.type,
    required this.message,
    this.hint,
    required this.color,
    this.shouldAdvance = false,
    this.shouldRetry = false,
  });

  // ══ Factory constructors ═══════════════════════════════════

  factory NoteFeedback.waiting() {
    return const NoteFeedback(
      type: FeedbackType.waiting,
      message: '🎸 Tap mic to start practicing',
      color: Color(0xFF888888),
    );
  }

  factory NoteFeedback.listening() {
    return const NoteFeedback(
      type: FeedbackType.listening,
      message: '👂 Play the highlighted note...',
      color: Color(0xFF2196F3),
    );
  }

  factory NoteFeedback.perfect() {
    return const NoteFeedback(
      type: FeedbackType.perfect,
      message: '🎯 Perfect!',
      color: Color(0xFF4CAF50),
      shouldAdvance: true,
    );
  }

  factory NoteFeedback.good() {
    return const NoteFeedback(
      type: FeedbackType.good,
      message: '✅ Good!',
      hint: 'Slightly off but great!',
      color: Color(0xFF8BC34A),
      shouldAdvance: true,
    );
  }

  factory NoteFeedback.acceptable() {
    return const NoteFeedback(
      type: FeedbackType.acceptable,
      message: '👍 Close enough!',
      hint: 'Keep practicing for precision',
      color: Color(0xFFCDDC39),
      shouldAdvance: true,
    );
  }

  factory NoteFeedback.close(int detected, int expected) {
    final diff = (expected - detected).abs();
    return NoteFeedback(
      type: FeedbackType.close,
      message: '🔄 Almost! Try again',
      hint: 'Off by $diff fret${diff > 1 ? 's' : ''}',
      color: const Color(0xFFFFC107),
      shouldRetry: true,
    );
  }

  factory NoteFeedback.tooLow(int detected, int expected) {
    final diff = expected - detected;
    final frets = diff > 2 ? '$diff frets' : (diff == 2 ? '2 frets' : '1 fret');
    return NoteFeedback(
      type: FeedbackType.tooLow,
      message: '📈 Play higher',
      hint: 'Move up $frets',
      color: const Color(0xFFFF9800),
      shouldRetry: true,
    );
  }

  factory NoteFeedback.tooHigh(int detected, int expected) {
    final diff = detected - expected;
    final frets = diff > 2 ? '$diff frets' : (diff == 2 ? '2 frets' : '1 fret');
    return NoteFeedback(
      type: FeedbackType.tooHigh,
      message: '📉 Play lower',
      hint: 'Move down $frets',
      color: const Color(0xFFFF5722),
      shouldRetry: true,
    );
  }

  factory NoteFeedback.wrong() {
    return const NoteFeedback(
      type: FeedbackType.wrong,
      message: '🎯 Check the fretboard',
      hint: 'Look at the highlighted position',
      color: Color(0xFFE53935),
      shouldRetry: true,
    );
  }

  /// Create feedback based on match quality
  factory NoteFeedback.fromQuality(String quality, int detected, int expected) {
    switch (quality) {
      case 'perfect':
        return NoteFeedback.perfect();
      case 'good':
        return NoteFeedback.good();
      case 'acceptable':
        return NoteFeedback.acceptable();
      case 'close':
        return NoteFeedback.close(detected, expected);
      default:
        if (detected < expected) {
          return NoteFeedback.tooLow(detected, expected);
        } else {
          return NoteFeedback.tooHigh(detected, expected);
        }
    }
  }
}