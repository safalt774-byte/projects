import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:projects/services/api_service.dart';
import 'package:projects/services/app_feedback_service.dart';
import 'package:projects/widgets/app_page_route.dart';
import 'practice_page.dart';

class PdfViewPage extends StatefulWidget {
  final String pdfPath;
  const PdfViewPage({super.key, required this.pdfPath});

  @override
  State<PdfViewPage> createState() => _PdfViewPageState();
}

class _PdfViewPageState extends State<PdfViewPage> {
  bool _processing = false;
  String _statusMessage = '';

  Future<void> _processSheet() async {
    AppFeedbackService.instance.playTick();
    setState(() { _processing = true; _statusMessage = 'Uploading...'; });

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() => _statusMessage = 'Processing music sheet...\nThis may take 1-2 minutes.');

      final result = await ApiService.processSheet(File(widget.pdfPath));
      if (!mounted) return;

      if (result.notes.isEmpty) {
        setState(() { _processing = false; _statusMessage = ''; });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No notes found'), backgroundColor: Colors.orange));
        return;
      }

      Navigator.pushReplacement(context, AppPageRoute.fadeScale(page: PracticePage(
        notes: result.notes,
        audioUrl: result.audioUrl,
        audioBase64: result.audioBase64,
        jobId: result.jobId,
        totalPages: result.totalPages,
        isMultiPage: result.isMultiPage,
      )));
    } catch (e) {
      if (!mounted) return;
      setState(() { _processing = false; _statusMessage = ''; });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red, duration: const Duration(seconds: 6)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(title: const Text('Music Sheet'), backgroundColor: const Color(0xFF16213E), foregroundColor: Colors.white),
      body: _processing
          ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: Color(0xFF4CAF50), strokeWidth: 3),
        const SizedBox(height: 28),
        Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6)),
      ])))
          : PDFView(filePath: widget.pdfPath),
      bottomNavigationBar: _processing ? null : SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: ElevatedButton.icon(
            icon: const Icon(Icons.queue_music), label: const Text('Process Sheet'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _processSheet),
      )),
    );
  }
}