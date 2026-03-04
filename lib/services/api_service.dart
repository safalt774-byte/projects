import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_event.dart';
import 'midi_mapper.dart';

class SheetProcessResult {
  final List<NoteEvent> notes;
  final String audioUrl;
  final String? audioBase64;
  final String jobId;
  final int totalPages;
  final bool isMultiPage;

  const SheetProcessResult({
    required this.notes,
    required this.audioUrl,
    this.audioBase64,
    required this.jobId,
    required this.totalPages,
    required this.isMultiPage,
  });
}

class PageResult {
  final List<NoteEvent> notes;
  final String audioUrl;
  final String? audioBase64;
  final int pageNum;

  const PageResult({
    required this.notes,
    required this.audioUrl,
    this.audioBase64,
    required this.pageNum,
  });
}


class ApiService {
  // NOTE: removed accidental trailing space here which caused malformed hostnames
  // Use a clean default (no trailing spaces). Users should replace this via Server Settings.
  static const String _defaultUrl =
      'https://white-raymond-pdt-until.trycloudflare.com';

  static String _baseUrl = _defaultUrl;
  /// Notifier that emits the current base URL whenever it changes. UI code
  /// can listen to this to update immediately after a save.
  static final ValueNotifier<String> baseUrlNotifier = ValueNotifier(_baseUrl);

  static const String _prefKey = 'server_base_url';

  /// Current server URL.
  static String get baseUrl => _baseUrl;

  /// Load saved URL from disk (call once at app start).
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey) ?? _defaultUrl;
    // sanitize loaded value: trim, remove internal whitespace, ensure scheme, strip trailing slash
    _baseUrl = _sanitizeUrl(raw);
    // keep notifier in sync
    baseUrlNotifier.value = _baseUrl;
  }

  /// Update the server URL and persist it.
  static Future<void> setBaseUrl(String url) async {
    // Sanitize input and persist
    _baseUrl = _sanitizeUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _baseUrl);
    // notify listeners
    baseUrlNotifier.value = _baseUrl;
  }

  /// Reset the saved base URL to the built-in default and notify listeners.
  static Future<void> resetToDefault() async {
    _baseUrl = _defaultUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _baseUrl);
    baseUrlNotifier.value = _baseUrl;
  }

  /// Helper that returns a sanitized copy of the current in-memory base URL.
  static String _cleanBaseUrl() => _sanitizeUrl(_baseUrl);

  /// Test if the server is reachable.
  static Future<bool> testConnection([String? url]) async {
    final testUrl = url ?? _cleanBaseUrl();
    try {
      final uri = Uri.parse('${testUrl.endsWith('/') ? testUrl.substring(0, testUrl.length - 1) : testUrl}/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Map<String, String> get _headers => {};

  static List<NoteEvent> _parseNotes(List<dynamic> rawNotes) {
    final events = <NoteEvent>[];
    for (final raw in rawNotes) {
      final map = raw as Map<String, dynamic>;
      final pitch = map['pitch'] as int;
      final pos = MidiMapper.toStringFret(pitch);
      if (pos == null) continue;
      events.add(NoteEvent.fromJson(map, stringIndex: pos.$1, fret: pos.$2));
    }
    return events;
  }

  /// Upload and process PDF. For large files, only page 1 is processed.
  static Future<SheetProcessResult> processSheet(File pdfFile) async {
    final base = _cleanBaseUrl();
    final endpoint = '$base/process-sheet/';
    // Helpful debug print to surface malformed URLs in logs during development.
    debugPrint('⤴️ processSheet endpoint: $endpoint');
    Uri uri;
    try {
      uri = Uri.parse(endpoint);
    } catch (e) {
      // Provide a friendly error that points the developer/user to the settings page
      throw Exception('Invalid server endpoint: "$endpoint".\nPlease open Server Settings and verify the URL (no spaces, correct domain).\nParse error: $e');
    }
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    request.files.add(await http.MultipartFile.fromPath(
      'file', pdfFile.path,
      filename: pdfFile.path.split(Platform.pathSeparator).last,
    ));

    final streamed = await request.send().timeout(
      const Duration(seconds: 360),
      onTimeout: () => throw Exception('Processing timed out'),
    );

    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      try {
        throw Exception(jsonDecode(body)['detail'] ?? body);
      } catch (_) {
        throw Exception(body);
      }
    }

    final json = jsonDecode(body) as Map<String, dynamic>;

    return SheetProcessResult(
      notes: _parseNotes(json['notes'] as List),
      audioUrl: '$base/${json['audioUrl']}',
      audioBase64: json['audioBase64'] as String?,
      jobId: json['jobId'] as String,
      totalPages: json['totalPages'] as int? ?? 1,
      isMultiPage: json['isMultiPage'] as bool? ?? false,
    );
  }

  /// Start processing a page in the background (returns immediately)
  static Future<void> startPageProcessing(String jobId, int pageNum) async {
    final base = _cleanBaseUrl();
    final uri = Uri.parse('$base/process-page/?job_id=$jobId&page_num=$pageNum');

    final response = await http.post(uri, headers: _headers).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Page $pageNum start request timed out'),
    );

    if (response.statusCode != 200) {
      try {
        throw Exception(jsonDecode(response.body)['detail'] ?? response.body);
      } catch (_) {
        throw Exception(response.body);
      }
    }

    // Response is just {"status": "processing"} — we don't need to parse notes here
    debugPrint('📤 Page $pageNum processing started on backend');
  }

  /// Poll until a page is done processing, then return the result
  static Future<PageResult> pollPageUntilDone(String jobId, int pageNum, {
    Duration interval = const Duration(seconds: 5),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final base = _cleanBaseUrl();
        final uri = Uri.parse('$base/status/?job_id=$jobId&page_num=$pageNum'.replaceFirst('/status', '/page-status'));

        final response = await http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 15),
        );

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final status = json['status'] as String?;

          if (status == 'done') {
            debugPrint('✅ Page $pageNum processing complete');
            return PageResult(
              notes: _parseNotes(json['notes'] as List),
              audioUrl: '$base/${json['audioUrl']}',
              audioBase64: json['audioBase64'] as String?,
              pageNum: json['pageNum'] as int,
            );
          }

          // Still processing — wait and poll again
          debugPrint('⏳ Page $pageNum still processing...');
        } else if (response.statusCode == 500) {
          final detail = jsonDecode(response.body)['detail'] ?? 'Processing failed';
          throw Exception('Page $pageNum failed: $detail');
        }
      } catch (e) {
        if (e.toString().contains('failed:')) rethrow;
        // Network hiccup during poll — just retry
        debugPrint('⚠️ Poll error for page $pageNum: $e');
      }

      await Future.delayed(interval);
    }

    throw Exception('Page $pageNum processing timed out after ${timeout.inMinutes} minutes');
  }

  /// Convenience: start processing + poll until done
  static Future<PageResult> processPage(String jobId, int pageNum) async {
    await startPageProcessing(jobId, pageNum);
    return pollPageUntilDone(jobId, pageNum);
  }

  /// Request the backend to concatenate all per-page WAVs into one file.
  /// Returns the combined audio URL/base64 and per-page time offsets.
  static Future<CombinedAudioResult> combineAudio(String jobId) async {
    final base = _cleanBaseUrl();
    final uri = Uri.parse('$base/combine-audio/?job_id=$jobId');

    final response = await http.get(uri, headers: _headers).timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Combine audio timed out'),
    );

    if (response.statusCode != 200) {
      try {
        throw Exception(jsonDecode(response.body)['detail'] ?? response.body);
      } catch (_) {
        throw Exception(response.body);
      }
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final offsets = (json['pageOffsetsMs'] as List).map((e) => (e as num).toDouble()).toList();

    return CombinedAudioResult(
      audioUrl: '$base/${json['audioUrl']}',
      audioBase64: json['audioBase64'] as String?,
      pageOffsetsMs: offsets,
    );
  }

  /// Sanitizes a URL from prefs or user input: trims, removes internal whitespace,
  /// removes non-printable chars, ensures it starts with http(s):// and strips trailing slash.
  static String _sanitizeUrl(String raw) {
    var s = raw.trim();
    // remove any whitespace characters that might have been inserted
    s = s.replaceAll(RegExp(r'\s+'), '');
    // remove non-printable / control characters
    s = s.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(s)) {
      s = 'https://' + s;
    }
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  /// Public wrapper for UI code to preview/validate a sanitized URL before saving.
  static String sanitizeUrl(String raw) => _sanitizeUrl(raw);
}

class CombinedAudioResult {
  final String audioUrl;
  final String? audioBase64;
  final List<double> pageOffsetsMs;

  const CombinedAudioResult({
    required this.audioUrl,
    this.audioBase64,
    required this.pageOffsetsMs,
  });
}