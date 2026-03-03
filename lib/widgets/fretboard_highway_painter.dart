import 'package:flutter/material.dart';
import '../models/note_event.dart';

/// Scrolling guitar tab view.
/// Playhead is fixed at 30% from left.
/// Notes scroll from right → left underneath it.
/// Like Guitar Hero / real tab sheet that extends beyond the screen.
class FretboardHighwayPainter extends CustomPainter {
  final List<NoteEvent> notes;
  final double songPositionMs;

  static const List<Color> stringColors = [
    Color(0xFFE53935), // e
    Color(0xFFFB8C00), // B
    Color(0xFFFFD600), // G
    Color(0xFF43A047), // D
    Color(0xFF1E88E5), // A
    Color(0xFF8E24AA), // E
  ];

  static const List<String> stringNames = ['e', 'B', 'G', 'D', 'A', 'E'];
  static const int numFrets = 12;

  // Playhead position (fixed on screen)
  static const double playheadRatio = 0.3; // 30% from left

  // Time scale: how many pixels = 1 second
  // Higher = more spacious, notes farther apart
  static const double pixelsPerSecond = 180.0;

  const FretboardHighwayPainter({
    required this.notes,
    required this.songPositionMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Layout ──────────────────────────────────────────────────
    const double labelW  = 40.0;
    const double topPad  = 8.0;
    const double botPad  = 28.0;

    final double boardLeft = labelW;
    final double boardTop  = topPad;
    final double boardW    = size.width - labelW - 8;
    final double boardH    = (size.height - topPad - botPad).clamp(120.0, double.infinity);

    final double stringGap = boardH / 5;
    final double fretGap   = boardW / numFrets;

    // Fixed playhead position on screen
    final double playheadX = boardLeft + boardW * playheadRatio;

    // ── Background ──────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0D0D1A),
    );

    // ── Fretboard wood ──────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(boardLeft, boardTop, boardW, boardH),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF2A1F0F),
    );

    // ── Nut ─────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(boardLeft, boardTop),
      Offset(boardLeft, boardTop + boardH),
      Paint()..color = const Color(0xFFF5E6C8)..strokeWidth = 4,
    );

    // ── Fret lines ──────────────────────────────────────────────
    for (int i = 1; i <= numFrets; i++) {
      final x = boardLeft + i * fretGap;
      canvas.drawLine(
        Offset(x, boardTop),
        Offset(x, boardTop + boardH),
        Paint()..color = const Color(0xFF8B7355)..strokeWidth = 1.5,
      );
    }

    // ── Fret numbers ────────────────────────────────────────────
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 1; i <= numFrets; i++) {
      final x = boardLeft + (i - 0.5) * fretGap;
      tp.text = TextSpan(
        text: '$i',
        style: const TextStyle(
          color: Color(0xFF888888),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, boardTop + boardH + 4));
    }

    // ── Guitar strings ──────────────────────────────────────────
    for (int s = 0; s < 6; s++) {
      final y = boardTop + s * stringGap;
      final thickness = 0.9 + s * 0.3;
      canvas.drawLine(
        Offset(boardLeft, y),
        Offset(boardLeft + boardW, y),
        Paint()
          ..color = const Color(0xFFD4A84B)
          ..strokeWidth = thickness,
      );
    }

    // ── String labels ───────────────────────────────────────────
    for (int s = 0; s < 6; s++) {
      final y = boardTop + s * stringGap;
      tp.text = TextSpan(
        text: stringNames[s],
        style: TextStyle(
          color: stringColors[s].withOpacity(0.9),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(
        labelW / 2 - tp.width / 2,
        y - tp.height / 2,
      ));
    }

    // ── Draw scrolling notes ────────────────────────────────────
    // Camera offset: how far "right" in time we've scrolled
    final double cameraOffsetMs = songPositionMs;

    for (final note in notes) {
      final s = note.stringIndex;
      final color = stringColors[s];

      // Convert note time → screen position
      // Notes scroll from right → left as time advances
      final noteScreenX = playheadX +
          ((note.startMs - cameraOffsetMs) / 1000.0) * pixelsPerSecond;

      final noteW = (note.durationMs / 1000.0) * pixelsPerSecond;

      // Skip notes outside visible area
      if (noteScreenX + noteW < boardLeft - 50) continue; // scrolled past
      if (noteScreenX > boardLeft + boardW + 50) continue; // not yet visible

      // Y position: centered on string
      final stringY = boardTop + s * stringGap;
      final boxH = stringGap * 0.7;
      final boxTop = stringY - boxH / 2;

      // Is playhead currently inside this note?
      final isActive = playheadX >= noteScreenX &&
          playheadX <= noteScreenX + noteW;

      // Note box
      final noteRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(noteScreenX, boxTop, noteW, boxH),
        Radius.circular(boxH / 2),
      );

      // Glow under active note
      if (isActive) {
        canvas.drawRRect(
          noteRect,
          Paint()
            ..color = color.withOpacity(0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }

      // Main note body
      canvas.drawRRect(
        noteRect,
        Paint()..color = isActive ? color : color.withOpacity(0.75),
      );

      // Left edge highlight
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(noteScreenX, boxTop, boxH * 0.25, boxH),
          Radius.circular(boxH / 2),
        ),
        Paint()..color = Colors.white.withOpacity(0.2),
      );

      // Fret number inside box
      final fretLabel = note.fret == 0 ? 'O' : '${note.fret}';
      tp.text = TextSpan(
        text: fretLabel,
        style: TextStyle(
          color: Colors.white,
          fontSize: (boxH * 0.5).clamp(11, 17),
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();

      if (noteW > 16) {
        tp.paint(canvas, Offset(
          noteScreenX + noteW / 2 - tp.width / 2,
          boxTop + boxH / 2 - tp.height / 2,
        ));
      }
    }

    // ── Fixed playhead (blue line) ──────────────────────────────
    canvas.drawLine(
      Offset(playheadX, boardTop),
      Offset(playheadX, boardTop + boardH),
      Paint()
        ..color = const Color(0xFF2196F3)
        ..strokeWidth = 3,
    );

    // Blue glow
    canvas.drawLine(
      Offset(playheadX, boardTop),
      Offset(playheadX, boardTop + boardH),
      Paint()
        ..color = const Color(0xFF2196F3).withOpacity(0.3)
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // White dot on playhead (shows active string)
    int activeLane = -1;
    for (final note in notes) {
      if (note.startMs <= songPositionMs &&
          songPositionMs <= note.startMs + note.durationMs) {
        activeLane = note.stringIndex;
        break;
      }
    }

    if (activeLane >= 0) {
      final dotY = boardTop + activeLane * stringGap;
      // Shadow
      canvas.drawCircle(
        Offset(playheadX + 1, dotY + 2),
        9,
        Paint()..color = Colors.black.withOpacity(0.4),
      );
      // White dot
      canvas.drawCircle(
        Offset(playheadX, dotY),
        9,
        Paint()..color = Colors.white,
      );
      // Shine
      canvas.drawCircle(
        Offset(playheadX - 2, dotY - 2),
        3,
        Paint()..color = Colors.white.withOpacity(0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant FretboardHighwayPainter old) =>
      old.songPositionMs != songPositionMs;
}