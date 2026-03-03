import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  static const String baseUrl =
      'https://unreconsidered-tabatha-electively.ngrok-free.dev';

  static Map<String, String> get _headers => {
    'ngrok-skip-browser-warning': 'true',
  };

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
    final uri = Uri.parse('$baseUrl/process-sheet/');
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
      audioUrl: '$baseUrl/${json['audioUrl']}',
      audioBase64: json['audioBase64'] as String?,
      jobId: json['jobId'] as String,
      totalPages: json['totalPages'] as int? ?? 1,
      isMultiPage: json['isMultiPage'] as bool? ?? false,
    );
  }

  /// Start processing a page in the background (returns immediately)
  static Future<void> startPageProcessing(String jobId, int pageNum) async {
    final uri = Uri.parse('$baseUrl/process-page/?job_id=$jobId&page_num=$pageNum');

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
        final uri = Uri.parse('$baseUrl/page-status/?job_id=$jobId&page_num=$pageNum');

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
              audioUrl: '$baseUrl/${json['audioUrl']}',
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
}