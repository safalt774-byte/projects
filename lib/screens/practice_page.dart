import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/fretboard_highway_painter.dart';
import '../models/note_event.dart';
import '../models/note_feedback.dart';
import '../services/api_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/pitch_detector.dart';

// ignore_for_file: use_build_context_synchronously

enum PracticeMode { watch, practice }

/// Audio + notes for one page — notes always start from 0ms (page-local time)
class PageData {
  final int pageNum;
  final List<NoteEvent> notes;
  String? audioPath;
  bool audioReady;

  PageData({
    required this.pageNum,
    required this.notes,
    this.audioPath,
    this.audioReady = false,
  });

  double get durationMs =>
      notes.isEmpty ? 1 : notes.last.startMs + notes.last.durationMs + 500;
}

class PracticePage extends StatefulWidget {
  final List<NoteEvent> notes;
  final String audioUrl;
  final String? audioBase64;
  final String jobId;
  final int totalPages;
  final bool isMultiPage;

  const PracticePage({
    super.key,
    required this.notes,
    required this.audioUrl,
    this.audioBase64,
    required this.jobId,
    required this.totalPages,
    required this.isMultiPage,
  });

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  // ── Per-page data ──────────────────────────────────────────
  final List<PageData> _pages = [];
  int  _activePageIdx  = 0;
  int  _pagesLoaded    = 1;
  bool _loadingPage    = false;
  int  _nextPageToLoad = 2;
  int  _pageRetryCount = 0;
  static const int _maxRetries = 3;

  // ── Combined timeline ──────────────────────────────────────
  /// All notes across all loaded pages, with start times offset so the
  /// whole song is one continuous timeline.
  List<NoteEvent> _allNotes = [];
  /// _pageOffsets[i] = global ms offset where page i starts in the timeline.
  final List<double> _pageOffsets = [];

  // ── Player ─────────────────────────────────────────────────
  AudioPlayer? _player;
  StreamSubscription? _posSub;
  StreamSubscription? _completeSub;

  // ── Pre-loaded next-page player ────────────────────────────
  AudioPlayer? _preloadedPlayer;
  int          _preloadedPageIdx   = -1;  // idx of the ready pre-loaded player
  int          _preloadingForIdx   = -1;  // idx currently being async-loaded

  bool _audioLoading  = true;
  bool _isPlaying     = false;
  bool _finished      = false;       // entire song finished (last page done)
  bool _jumpingToPage = false;

  // ── Animation ──────────────────────────────────────────────
  late Ticker _ticker;
  double _songPosMs  = 0;            // GLOBAL position in the combined timeline
  double _audioPosMs = 0;            // local audio position (per-page)
  final  _clock      = Stopwatch();

  // ── Tempo ──────────────────────────────────────────────────
  double _playbackRate = 1.0;
  static const double _tempoMin = 0.25, _tempoMax = 2.0, _tempoStep = 0.05;

  // ── Sync ───────────────────────────────────────────────────
  double _syncOffsetMs    = 0;
  bool   _showCalibration = false;

  // ── Practice mode ──────────────────────────────────────────
  AudioRecorderService? _recorder;
  PracticeMode _mode = PracticeMode.watch;
  NoteFeedback _feedback = NoteFeedback.waiting();
  int  _currentNoteIndex    = 0;
  int  _correctCount        = 0;
  int  _attemptCount        = 0;
  int  _consecutiveCorrect  = 0;
  int  _mistakeNoteIndex    = -1;
  DateTime? _lastFeedbackTime;
  static const _fbDebounce = Duration(milliseconds: 150);

  bool _wasPlayingBeforePause = false;

  // ── Countdown ──────────────────────────────────────────────
  bool _showCountdown  = false;
  int  _countdownValue = 3;
  Timer? _countdownTimer;

  // ── Streak tracking ────────────────────────────────────────
  int _lastStreakMilestone = 0;

  // ── Convenience ────────────────────────────────────────────
  PageData get _activePage => _pages[_activePageIdx];

  NoteEvent? get _currentNote =>
      _currentNoteIndex < _allNotes.length ? _allNotes[_currentNoteIndex] : null;

  double get _activePageOffset =>
      _activePageIdx < _pageOffsets.length ? _pageOffsets[_activePageIdx] : 0;

  double get _totalDurationMs =>
      _allNotes.isEmpty ? 1 : _allNotes.last.startMs + _allNotes.last.durationMs + 500;

  /// Rebuild the combined note timeline from all loaded pages.
  void _rebuildTimeline() {
    _allNotes = [];
    _pageOffsets.clear();
    double offset = 0;
    for (final pg in _pages) {
      _pageOffsets.add(offset);
      for (final n in pg.notes) {
        _allNotes.add(NoteEvent(
          pitch: n.pitch,
          startMs: n.startMs + offset,
          durationMs: n.durationMs,
          stringIndex: n.stringIndex,
          fret: n.fret,
        ));
      }
      offset += pg.durationMs;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  COUNTDOWN
  // ══════════════════════════════════════════════════════════

  void _startCountdown(VoidCallback onComplete) {
    _countdownTimer?.cancel();
    setState(() { _showCountdown = true; _countdownValue = 3; });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final next = _countdownValue - 1;
      if (next <= 0) {
        timer.cancel();
        setState(() { _showCountdown = false; });
        onComplete();
      } else {
        setState(() => _countdownValue = next);
      }
    });
  }

  // ══════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ══════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]).then((_) => _boot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
    ]);
    _countdownTimer?.cancel();
    _posSub?.cancel();
    _completeSub?.cancel();
    _ticker.dispose();
    _player?.dispose();
    try { _preloadedPlayer?.dispose(); } catch (e) { debugPrint('⚠️ preloadedPlayer dispose: $e'); }
    _preloadedPlayer = null;
    _recorder?.dispose();
    for (final pg in _pages) {
      if (pg.audioPath != null) {
        File(pg.audioPath!).delete().catchError((_) => File(pg.audioPath!));
      }
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPlayingBeforePause = _isPlaying;
      _pause();
    }
  }

  // ══════════════════════════════════════════════════════════
  //  BOOT
  // ══════════════════════════════════════════════════════════

  Future<void> _boot() async {
    setState(() => _audioLoading = true);

    final page1 = PageData(pageNum: 1, notes: List.from(widget.notes));

    String? path;
    if (widget.audioBase64 != null && widget.audioBase64!.isNotEmpty) {
      path = await _saveBase64(widget.audioBase64!);
    }
    path ??= await _downloadWav(widget.audioUrl);

    page1.audioPath = path;
    page1.audioReady = path != null;
    _pages.add(page1);
    _rebuildTimeline();

    if (mounted) setState(() => _audioLoading = false);

    // Start countdown before auto-playing
    _startCountdown(() => _play());

    if (widget.isMultiPage && widget.totalPages > 1) {
      _loadNextPage();
    }
  }

  // ══════════════════════════════════════════════════════════
  //  PLAYER
  // ══════════════════════════════════════════════════════════

  Future<bool> _playPageAudio(int pageIdx, {AudioPlayer? preloadedPlayer}) async {
    if (pageIdx >= _pages.length) return false;
    final pg = _pages[pageIdx];
    if (pg.audioPath == null || !pg.audioReady) return false;

    debugPrint('🔧 _playPageAudio page=${pg.pageNum} (preloaded=${preloadedPlayer != null})');

    await _disposePlayer();

    final player = preloadedPlayer ?? AudioPlayer();
    _player = player;

    // Completes on the first onPositionChanged event, confirming audio output.
    final audioStarted = Completer<void>();

    _posSub = player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      if (!audioStarted.isCompleted) audioStarted.complete();
      final newPos = _activePageOffset + pos.inMilliseconds.toDouble();
      // Only sync forward — never let a late event snap the animation backward
      final effectivePos = _audioPosMs + _clock.elapsedMilliseconds * _playbackRate;
      if (newPos >= effectivePos) {
        _audioPosMs = newPos;
        _clock.reset();
        _clock.start();
      }
    });

    _completeSub = player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      debugPrint('🏁 Page ${pg.pageNum} audio complete');
      _onPageAudioComplete();
    });

    try {
      if (preloadedPlayer == null) {
        await player.setSource(DeviceFileSource(pg.audioPath!));
      }
      await player.setPlaybackRate(_playbackRate);
      await player.resume();
      // Wait for the first onPositionChanged event so the clock and ticker
      // only start once audio is actually producing output (avoids the 2-4s
      // window on Android where animation runs ahead of silent audio).
      // Falls back after 3 s so the app never hangs indefinitely.
      await audioStarted.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
      _clock.reset();
      _clock.start();
      debugPrint('▶️ Page ${pg.pageNum} playing (clock started)');
      return true;
    } catch (e) {
      debugPrint('❌ _playPageAudio failed: $e');
      return false;
    }
  }

  /// Pre-load the audio source for [pageIdx] into a standby [AudioPlayer] so
  /// that the page transition can resume playback immediately (no buffering gap).
  Future<void> _preloadAudio(int pageIdx) async {
    if (pageIdx >= _pages.length) return;
    if (_preloadedPageIdx == pageIdx) return;   // already ready
    if (_preloadingForIdx  == pageIdx) return;  // already loading
    final pg = _pages[pageIdx];
    if (!pg.audioReady || pg.audioPath == null) return;

    // Dispose any stale pre-loaded player for a different page.
    try { _preloadedPlayer?.dispose(); } catch (e) { debugPrint('⚠️ preloadedPlayer dispose: $e'); }
    _preloadedPlayer  = null;
    _preloadedPageIdx = -1;

    _preloadingForIdx = pageIdx; // Mark as in-progress before first await.

    debugPrint('🔄 Pre-loading audio for page ${pg.pageNum}…');
    final p = AudioPlayer();
    try {
      await p.setSource(DeviceFileSource(pg.audioPath!));
      if (mounted && _preloadingForIdx == pageIdx) {
        _preloadedPlayer  = p;
        _preloadedPageIdx = pageIdx;
        _preloadingForIdx = -1;
        debugPrint('✅ Pre-loaded page ${pg.pageNum}');
      } else {
        // Cancelled by a later request or widget disposed.
        p.dispose();
        if (_preloadingForIdx == pageIdx) _preloadingForIdx = -1;
      }
    } catch (e) {
      debugPrint('⚠️ Pre-load page ${pg.pageNum} failed: $e');
      p.dispose();
      if (_preloadingForIdx == pageIdx) _preloadingForIdx = -1;
    }
  }

  Future<void> _disposePlayer() async {
    _posSub?.cancel();
    _completeSub?.cancel();
    _posSub = null;
    _completeSub = null;
    // Fire-and-forget: do NOT await stop/dispose.
    // On Android, await _player?.stop() can block for 3-4 seconds which
    // causes the animation to run without audio during page transitions.
    final old = _player;
    _player = null;
    Future.microtask(() async {
      try { await old?.stop(); } catch (_) {}
      try { old?.dispose(); } catch (_) {}
    });
  }

  // ══════════════════════════════════════════════════════════
  //  PAGE AUDIO COMPLETE — auto-advance or finish
  // ══════════════════════════════════════════════════════════

  void _onPageAudioComplete() {
    if (_mode != PracticeMode.watch) return;
    if (_jumpingToPage) return;

    final nextIdx = _activePageIdx + 1;

    // ★ FIX 1: Snap _songPosMs to the exact boundary of the next page
    if (nextIdx < _pageOffsets.length) {
      _songPosMs = _pageOffsets[nextIdx];
    } else if (nextIdx < _pages.length) {
      double offset = 0;
      for (int i = 0; i < nextIdx && i < _pages.length; i++) {
        offset += _pages[i].durationMs;
      }
      _songPosMs = offset;
    }

    // If next page is ready → auto-advance
    if (nextIdx < _pages.length && _pages[nextIdx].audioReady) {
      debugPrint('🎵 Auto-advancing to page ${nextIdx + 1}');
      _clock.stop();
      if (_ticker.isActive) _ticker.stop();
      _autoAdvanceToPage(nextIdx);
      return;
    }

    // No next page ready → song is done (or still processing)
    _clock.stop();
    if (_ticker.isActive) _ticker.stop();
    _disposePlayer();

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _finished  = true;
      });
    }
  }

  /// Auto-advance: swap audio and restart animation immediately.
  Future<void> _autoAdvanceToPage(int pageIdx) async {
    if (_jumpingToPage) return;
    setState(() { _jumpingToPage = true; });

    _clock.stop();
    if (_ticker.isActive) _ticker.stop();

    // Pull the pre-loaded player if it's ready for this exact page.
    AudioPlayer? preloaded;
    if (_preloadedPageIdx == pageIdx) {
      preloaded         = _preloadedPlayer;
      _preloadedPlayer  = null;
      _preloadedPageIdx = -1;
    }

    await _disposePlayer();

    _activePageIdx = pageIdx;
    final pageStart = _activePageOffset;

    _songPosMs  = pageStart;
    _audioPosMs = pageStart;
    _clock.reset();

    final ok = await _playPageAudio(pageIdx, preloadedPlayer: preloaded);

    if (ok) {
      // _playPageAudio waited for the first onPositionChanged event, so
      // clock is already running and audio is confirmed to be playing.
      setState(() {
        _jumpingToPage = false;
        _isPlaying     = true;
        _finished      = false;
      });
      if (!_ticker.isActive) _ticker.start();
      // Begin buffering the page after this one while this one plays.
      _preloadAudio(pageIdx + 1);
    } else {
      if (_ticker.isActive) _ticker.stop();
      setState(() {
        _jumpingToPage = false;
        _isPlaying     = false;
        _finished      = true;
      });
      debugPrint('❌ Auto-advance to page ${pageIdx + 1} failed');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  JUMP TO PAGE
  // ══════════════════════════════════════════════════════════

  Future<void> _jumpToPage(int pageIdx) async {
    if (pageIdx >= _pages.length) return;
    if (_jumpingToPage) return;

    setState(() { _jumpingToPage = true; });

    _clock.stop();
    if (_ticker.isActive) _ticker.stop();

    // Discard the pre-loaded player — user is jumping to a possibly different page.
    try { _preloadedPlayer?.dispose(); } catch (e) { debugPrint('⚠️ preloadedPlayer dispose: $e'); }
    _preloadedPlayer  = null;
    _preloadedPageIdx = -1;
    _preloadingForIdx = -1;

    await _disposePlayer();

    _activePageIdx = pageIdx;
    final globalStart = _activePageOffset;
    _songPosMs  = globalStart;
    _audioPosMs = globalStart;
    _currentNoteIndex = 0;
    _clock.reset();

    final ok = await _playPageAudio(pageIdx);

    if (ok) {
      // clock started inside _playPageAudio (after first position event)
      setState(() {
        _isPlaying     = true;
        _finished      = false;
        _jumpingToPage = false;
        _mode = PracticeMode.watch;
      });
      if (!_ticker.isActive) _ticker.start();
      // Pre-load the next page so subsequent auto-advance is seamless.
      _preloadAudio(pageIdx + 1);
    } else {
      setState(() {
        _finished      = false;
        _jumpingToPage = false;
      });
      debugPrint('❌ Jump to page ${pageIdx + 1} failed');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  BACKGROUND PAGE LOADING
  // ══════════════════════════════════════════════════════════

  Future<void> _loadNextPage() async {
    if (_nextPageToLoad > widget.totalPages || _loadingPage) return;
    final pageNum = _nextPageToLoad;
    _loadingPage = true;
    _pageRetryCount = 0;
    if (mounted) setState(() {});

    debugPrint('📄 BG loading page $pageNum/${widget.totalPages}');

    try {
      await ApiService.startPageProcessing(widget.jobId, pageNum);
      if (!mounted) return;
      final result = await ApiService.pollPageUntilDone(widget.jobId, pageNum);
      if (!mounted) return;

      final notes = result.notes;

      String? audioPath;
      if (result.audioBase64 != null && result.audioBase64!.isNotEmpty) {
        audioPath = await _saveBase64(result.audioBase64!);
      }
      audioPath ??= await _downloadWav(result.audioUrl);

      final pg = PageData(
        pageNum: pageNum,
        notes: notes,
        audioPath: audioPath,
        audioReady: audioPath != null,
      );
      _pages.add(pg);
      _rebuildTimeline();

      setState(() {
        _pagesLoaded    = pageNum;
        _loadingPage    = false;
        _nextPageToLoad = pageNum + 1;
      });

      debugPrint('✅ Page $pageNum: ${notes.length} notes, audio=${audioPath != null}');

      // If we're actively playing the page just before this one, pre-load its
      // audio now so the transition can resume instantly.
      if (_isPlaying && _activePageIdx == _pages.length - 2) {
        _preloadAudio(_pages.length - 1);
      }

      if (_nextPageToLoad <= widget.totalPages && mounted) {
        _loadNextPage();
      }
    } catch (e) {
      debugPrint('⚠️ Page $pageNum failed: $e');
      _loadingPage = false;
      _pageRetryCount++;
      if (_pageRetryCount < _maxRetries) {
        await Future.delayed(const Duration(seconds: 5));
        if (mounted) _loadNextPage();
      } else {
        _pageRetryCount = 0;
        _nextPageToLoad = pageNum + 1;
        if (_nextPageToLoad <= widget.totalPages && mounted) _loadNextPage();
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  //  PLAYBACK CONTROLS
  // ══════════════════════════════════════════════════════════

  Future<void> _play() async {
    if (_finished) { await _replayFromStart(); return; }

    setState(() { _mode = PracticeMode.watch; });

    if (_player == null) {
      setState(() { _jumpingToPage = true; });
      _songPosMs = _activePageOffset; _audioPosMs = _activePageOffset;
      final ok = await _playPageAudio(_activePageIdx);
      if (ok) {
        // clock started inside _playPageAudio (after first position event)
        setState(() { _isPlaying = true; _jumpingToPage = false; });
        if (!_ticker.isActive) _ticker.start();
        // Begin buffering the next page while page 1 is playing.
        _preloadAudio(_activePageIdx + 1);
      } else {
        setState(() { _jumpingToPage = false; });
      }
    } else {
      try { await _player!.resume(); } catch (_) {}
      _clock.reset(); _clock.start();
      setState(() => _isPlaying = true);
      if (!_ticker.isActive) _ticker.start();
    }
  }

  Future<void> _pause() async {
    _clock.stop();
    if (_ticker.isActive) _ticker.stop();
    _audioPosMs = _songPosMs;
    try { await _player?.pause(); } catch (_) {}
    await _stopRecording();
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _replayFromStart() async {
    await _jumpToPage(0);
  }

  Future<void> _setTempo(double rate) async {
    final c = rate.clamp(_tempoMin, _tempoMax);
    try { await _player?.setPlaybackRate(c); } catch (_) {}
    _clock.reset(); _clock.start();
    setState(() => _playbackRate = c);
  }

  // ══════════════════════════════════════════════════════════
  //  ANIMATION TICK
  // ══════════════════════════════════════════════════════════

  void _onTick(Duration _) {
    if (!mounted || !_isPlaying || _mode != PracticeMode.watch) return;
    if (_jumpingToPage) return;

    final ms = _audioPosMs + _clock.elapsedMilliseconds * _playbackRate + _syncOffsetMs;

    setState(() {
      _songPosMs = ms.clamp(0.0, _totalDurationMs);
      for (int i = 0; i < _allNotes.length; i++) {
        final n = _allNotes[i];
        if (n.startMs <= _songPosMs && _songPosMs <= n.startMs + n.durationMs) {
          _currentNoteIndex = i;
          break;
        }
      }
    });
  }

  // ══════════════════════════════════════════════════════════
  //  AUDIO FILE HELPERS
  // ══════════════════════════════════════════════════════════

  Future<String?> _saveBase64(String b64) async {
    try {
      final bytes = base64Decode(b64);
      if (bytes.length < 1000) return null;
      final dir = await getTemporaryDirectory();
      final p = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      await File(p).writeAsBytes(bytes);
      debugPrint('💾 b64 audio: $p (${bytes.length}B)');
      return p;
    } catch (e) { debugPrint('❌ b64 save: $e'); return null; }
  }

  Future<String?> _downloadWav(String url, {int retries = 3}) async {
    for (int i = 1; i <= retries; i++) {
      try {
        debugPrint('📥 WAV download $i/$retries: $url');
        final req = await HttpClient().getUrl(Uri.parse(url));
        final res = await req.close().timeout(const Duration(seconds: 180));
        if (res.statusCode != 200) { debugPrint('❌ HTTP ${res.statusCode}'); continue; }
        final bytes = await res.fold<List<int>>([], (prev, e) => prev..addAll(e));
        if (bytes.length < 1000) { debugPrint('❌ Too small (${bytes.length}B)'); continue; }
        if (bytes.length >= 4 && String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') {
          debugPrint('❌ Not WAV header'); continue;
        }
        final dir = await getTemporaryDirectory();
        final p = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
        await File(p).writeAsBytes(bytes);
        debugPrint('💾 $p (${bytes.length}B)');
        return p;
      } catch (e) { debugPrint('❌ Download $i: $e'); }
      if (i < retries) await Future.delayed(Duration(seconds: 3 * i));
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════
  //  PRACTICE MODE
  // ══════════════════════════════════════════════════════════

  Future<void> _startPracticeMode() async {
    if (_recorder == null) {
      _recorder = AudioRecorderService();
      if (!await _recorder!.init()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mic permission needed'), backgroundColor: Colors.orange),
          );
        }
        _recorder = null;
        return;
      }
    }
    if (_isPlaying) await _pause();
    _lastStreakMilestone = 0;
    setState(() {
      _mode = PracticeMode.practice;
      _currentNoteIndex = 0;
      _songPosMs = _allNotes.isNotEmpty ? _allNotes[0].startMs : 0;
      _feedback = NoteFeedback.listening();
      _correctCount = 0; _attemptCount = 0;
      _consecutiveCorrect = 0; _mistakeNoteIndex = -1;
      _isPlaying = true;
    });
    try { await _recorder!.startRecording(onAudioChunk: _processAudioChunk); } catch (_) {}
  }

  Future<void> _stopPracticeMode() async {
    await _stopRecording();
    setState(() { _mode = PracticeMode.watch; _feedback = NoteFeedback.waiting(); _isPlaying = false; });
  }

  Future<void> _stopRecording() async {
    if (_recorder == null || !_recorder!.isRecording) return;
    await _recorder!.stopRecording();
  }

  void _processAudioChunk(Uint8List data) {
    if (_mode != PracticeMode.practice || _currentNote == null) return;
    final now = DateTime.now();
    if (_lastFeedbackTime != null && now.difference(_lastFeedbackTime!) < _fbDebounce) return;

    final result = PitchDetector.detectPitchDetailed(data);
    if (result == null) {
      if (_feedback.type != FeedbackType.listening) setState(() => _feedback = NoteFeedback.listening());
      return;
    }
    _lastFeedbackTime = now;
    setState(() => _attemptCount++);

    final quality = PitchDetector.matchQuality(result.midiNote, _currentNote!.pitch, centsOffset: result.centsOffset);
    final fb = NoteFeedback.fromQuality(quality, result.midiNote, _currentNote!.pitch);
    setState(() => _feedback = fb);

    if (fb.shouldAdvance) {
      _correctCount++; _consecutiveCorrect++;
      // Streak milestone tracking
      if (_consecutiveCorrect >= 3 && _consecutiveCorrect > _lastStreakMilestone &&
          (_consecutiveCorrect == 3 || _consecutiveCorrect == 5 || _consecutiveCorrect % 10 == 0)) {
        _lastStreakMilestone = _consecutiveCorrect;
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted || _mode != PracticeMode.practice) return;
        setState(() {
          if (_currentNoteIndex < _allNotes.length - 1) {
            _currentNoteIndex++;
            _songPosMs = _currentNote!.startMs;
            _feedback = NoteFeedback.listening();
          } else {
            _onPageAudioComplete();
          }
        });
      });
    } else if (fb.shouldRetry) {
      _consecutiveCorrect = 0;
      _lastStreakMilestone = 0;
      if (_mistakeNoteIndex != _currentNoteIndex) _mistakeNoteIndex = _currentNoteIndex;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  COMPUTED
  // ══════════════════════════════════════════════════════════

  double get _progress {
    if (_allNotes.isEmpty) return 0;
    if (_mode == PracticeMode.practice) {
      return ((_currentNoteIndex + 1) / _allNotes.length).clamp(0.0, 1.0);
    }
    return (_songPosMs / _totalDurationMs).clamp(0.0, 1.0);
  }

  static const _sn = ['e', 'B', 'G', 'D', 'A', 'E'];
  String get _noteLabel {
    final n = _currentNote;
    if (n == null) return 'Get ready...';
    return '${_sn[n.stringIndex]} string — ${n.fret == 0 ? 'Open' : 'Fret ${n.fret}'}';
  }

  double get _accuracy => _attemptCount == 0 ? 0 : (_correctCount / _attemptCount * 100);

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty && !_audioLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: Text('No notes found.', style: TextStyle(color: Colors.white70))),
      );
    }

    if (_audioLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: Color(0xFF4CAF50), strokeWidth: 3),
          const SizedBox(height: 24),
          const Text('Loading audio...', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Page 1/${widget.totalPages}',
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(child: Stack(children: [
        Column(children: [
          _buildTopBar(),

          if (widget.isMultiPage && _pagesLoaded < widget.totalPages)
            _buildProcessingBar(),

          if (_jumpingToPage)
            Container(
              width: double.infinity,
              color: const Color(0xFF2196F3).withAlpha(30),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 8),
                Text('Loading page audio…', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),

          if (_pages.isNotEmpty && !_activePage.audioReady)
            Container(
              width: double.infinity,
              color: Colors.orange.withAlpha(50),
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: const Text('⚠️ Audio unavailable — animation only',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange, fontSize: 11)),
            ),

          Expanded(child: CustomPaint(
            painter: FretboardHighwayPainter(
              notes: _allNotes,
              songPositionMs: _songPosMs,
            ),
            size: Size.infinite,
          )),

          // Page navigation bar (below fretboard)
          if (widget.isMultiPage) _buildPageNavBar(),

          _buildFeedbackBar(),
          _buildControlsBar(),
        ]),
        if (_showCalibration)
          Positioned(right: 0, top: 0, bottom: 0, child: _buildCalibrationPanel()),

        // ── Countdown overlay ────────────────────────────────
        if (_showCountdown)
          _buildCountdownOverlay(),

        // ── Completion overlay ───────────────────────────────
        if (_finished && _mode == PracticeMode.watch)
          _buildCompletionOverlay(),
      ])),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  PAGE NAVIGATION BAR
  // ══════════════════════════════════════════════════════════

  Widget _buildPageNavBar() {
    return Container(
      color: const Color(0xFF16213E),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [
        Text('Page ${_activePageIdx + 1}',
            style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (int i = 0; i < _pages.length; i++) ...[
              _buildPageButton(i),
              const SizedBox(width: 4),
            ],
            if (_loadingPage && _nextPageToLoad <= widget.totalPages)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 10, height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38)),
                  const SizedBox(width: 4),
                  Text('P$_nextPageToLoad…', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ]),
              ),
          ]),
        )),
        if (_finished) ...[
          const SizedBox(width: 8),
          const Text('✓', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 14)),
        ],
      ]),
    );
  }

  Widget _buildPageButton(int pageIdx) {
    final pg = _pages[pageIdx];
    final isActive = pageIdx == _activePageIdx;
    final isReady = pg.audioReady;
    final isCurrentlyPlaying = isActive && _isPlaying;

    return GestureDetector(
      onTap: (isReady && !_jumpingToPage && !isCurrentlyPlaying)
          ? () => _jumpToPage(pageIdx)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF4CAF50)
              : isReady
                  ? const Color(0xFF4CAF50).withAlpha(40)
                  : Colors.white10,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? const Color(0xFF4CAF50)
                : isReady ? const Color(0xFF4CAF50).withAlpha(100) : Colors.white24,
            width: 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isCurrentlyPlaying)
            const Icon(Icons.volume_up, color: Colors.white, size: 11)
          else if (isReady)
            Icon(Icons.play_arrow, color: isActive ? Colors.white : const Color(0xFF4CAF50), size: 11)
          else
            const Icon(Icons.hourglass_empty, color: Colors.white38, size: 11),
          const SizedBox(width: 3),
          Text('Page ${pg.pageNum}',
            style: TextStyle(
              color: isActive ? Colors.white : isReady ? const Color(0xFF4CAF50) : Colors.white38,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  OTHER UI BUILDERS
  // ══════════════════════════════════════════════════════════

  Widget _buildProcessingBar() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF2196F3).withAlpha(38),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (_loadingPage) const SizedBox(width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2196F3))),
        if (_loadingPage) const SizedBox(width: 8),
        Text(
          _loadingPage
              ? 'Processing page $_nextPageToLoad/${widget.totalPages}…'
              : 'Pages $_pagesLoaded/${widget.totalPages} ready',
          style: const TextStyle(color: Color(0xFF2196F3), fontSize: 11),
        ),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFF16213E),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        GestureDetector(
          onTap: () { _pause(); Navigator.pop(context); },
          child: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(_noteLabel, style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 15, fontWeight: FontWeight.bold)),
          Text(
            'Note ${_currentNoteIndex + 1}/${_allNotes.length}'
            '${widget.isMultiPage ? ' • Page ${_activePageIdx + 1}/${widget.totalPages}' : ''}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ])),
        if (_mode == PracticeMode.watch) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: _playbackRate > _tempoMin
                    ? () => _setTempo(((_playbackRate - _tempoStep) * 100).round() / 100.0)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Icon(Icons.remove, color: _playbackRate > _tempoMin ? Colors.white : Colors.white24, size: 14),
                ),
              ),
              GestureDetector(
                onTap: () => _setTempo(1.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('${_playbackRate.toStringAsFixed(2)}x',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              GestureDetector(
                onTap: _playbackRate < _tempoMax
                    ? () => _setTempo(((_playbackRate + _tempoStep) * 100).round() / 100.0)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Icon(Icons.add, color: _playbackRate < _tempoMax ? Colors.white : Colors.white24, size: 14),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _showCalibration = !_showCalibration),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _showCalibration ? const Color(0xFF4CAF50) : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.tune, color: Colors.white, size: 14),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text('${(_progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ]),
    );
  }

  Widget _buildFeedbackBar() {
    final p = _mode == PracticeMode.practice;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: p ? _feedback.color.withAlpha(38) : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(children: [
        GestureDetector(
          onTap: p ? _stopPracticeMode : _startPracticeMode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: p ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(p ? Icons.stop : Icons.mic, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(p ? 'Stop' : 'Practice',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(p ? _feedback.message : 'Watch mode',
              style: TextStyle(color: p ? _feedback.color : Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
          if (p && _feedback.hint != null)
            Text(_feedback.hint!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ])),
        if (p && _mistakeNoteIndex >= 0 && _feedback.shouldRetry)
          GestureDetector(
            onTap: () => setState(() {
              _currentNoteIndex = _mistakeNoteIndex;
              _songPosMs = _allNotes[_mistakeNoteIndex].startMs;
              _feedback = NoteFeedback.listening();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF9800)),
              ),
              child: const Text('Retry',
                  style: TextStyle(color: Color(0xFFFF9800), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        if (p && _attemptCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text('${_accuracy.toStringAsFixed(0)}%',
                style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        if (p && _consecutiveCorrect >= 3)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFD600)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_fire_department, color: Colors.white, size: 12),
                const SizedBox(width: 2),
                Text('$_consecutiveCorrect',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _buildControlsBar() {
    final p = _mode == PracticeMode.practice;
    return Container(
      color: const Color(0xFF0F3460),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        if (!p) ...[
          SizedBox(width: 44, height: 44, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isPlaying ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
              shape: const CircleBorder(), padding: EdgeInsets.zero,
            ),
            onPressed: _jumpingToPage ? null : (_isPlaying ? _pause : _play),
            child: _jumpingToPage
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 24),
          )),
          const SizedBox(width: 8),
          SizedBox(width: 36, height: 36, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF37474F), shape: const CircleBorder(), padding: EdgeInsets.zero,
            ),
            onPressed: _jumpingToPage ? null : _replayFromStart,
            child: const Icon(Icons.replay, color: Colors.white, size: 18),
          )),
          const SizedBox(width: 12),
        ],
        if (p) ...[
          SizedBox(width: 36, height: 36, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF37474F), shape: const CircleBorder(), padding: EdgeInsets.zero,
            ),
            onPressed: _currentNoteIndex > 0
                ? () => setState(() {
                    _currentNoteIndex--;
                    _songPosMs = _currentNote!.startMs;
                    _feedback = NoteFeedback.listening();
                  })
                : null,
            child: const Icon(Icons.skip_previous, color: Colors.white, size: 18),
          )),
          const SizedBox(width: 8),
          SizedBox(width: 36, height: 36, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF37474F), shape: const CircleBorder(), padding: EdgeInsets.zero,
            ),
            onPressed: _currentNoteIndex < _allNotes.length - 1
                ? () => setState(() {
                    _currentNoteIndex++;
                    _songPosMs = _currentNote!.startMs;
                    _feedback = NoteFeedback.listening();
                  })
                : null,
            child: const Icon(Icons.skip_next, color: Colors.white, size: 18),
          )),
          const SizedBox(width: 12),
        ],
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress, minHeight: 6,
            backgroundColor: const Color(0xFF1A1A2E),
            valueColor: AlwaysStoppedAnimation<Color>(p ? const Color(0xFF2196F3) : const Color(0xFF4CAF50)),
          ),
        )),
        const SizedBox(width: 8),
        Text(
          _finished ? '✓ Done' : p ? '${_currentNoteIndex + 1}/${_allNotes.length}' : '',
          style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11),
        ),
      ]),
    );
  }

  Widget _buildCalibrationPanel() {
    return Container(
      width: 260, color: const Color(0xFF16213E), padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Sync', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          GestureDetector(
            onTap: () => setState(() => _showCalibration = false),
            child: const Icon(Icons.close, color: Colors.white54, size: 18),
          ),
        ]),
        const SizedBox(height: 16),
        Center(child: Text(
          '${_syncOffsetMs >= 0 ? '+' : ''}${_syncOffsetMs.toInt()} ms',
          style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 22, fontWeight: FontWeight.bold),
        )),
        Slider(
          value: _syncOffsetMs, min: -500, max: 500, divisions: 100,
          activeColor: const Color(0xFF4CAF50), inactiveColor: Colors.white24,
          onChanged: (val) => setState(() => _syncOffsetMs = val),
        ),
        const Spacer(),
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF37474F)),
          onPressed: () => setState(() => _syncOffsetMs = 0),
          child: const Text('Reset'),
        )),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  COUNTDOWN OVERLAY
  // ══════════════════════════════════════════════════════════

  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(179),
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_countdownValue),
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_countdownValue + 100),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, opacity, child) {
                    return Opacity(opacity: opacity, child: child);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_countdownValue',
                        style: TextStyle(
                          color: _countdownValue == 1
                              ? const Color(0xFF4CAF50)
                              : Colors.white,
                          fontSize: 96,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: const Color(0xFF4CAF50).withAlpha(128),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Get Ready...',
                          style: TextStyle(color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  COMPLETION OVERLAY
  // ══════════════════════════════════════════════════════════

  Widget _buildCompletionOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _finished = false),
        child: Container(
          color: Colors.black.withAlpha(191),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF4CAF50).withAlpha(128), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withAlpha(51),
                      blurRadius: 30, spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text('Song Complete!',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${_allNotes.length} notes played',
                        style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    if (widget.isMultiPage)
                      Text('${widget.totalPages} pages',
                          style: const TextStyle(color: Colors.white38, fontSize: 13)),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _buildCompletionButton(
                        icon: Icons.replay,
                        label: 'Replay',
                        color: const Color(0xFF4CAF50),
                        onTap: () { setState(() => _finished = false); _replayFromStart(); },
                      ),
                      const SizedBox(width: 16),
                      _buildCompletionButton(
                        icon: Icons.arrow_back,
                        label: 'Back',
                        color: const Color(0xFF37474F),
                        onTap: () => Navigator.pop(context),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}