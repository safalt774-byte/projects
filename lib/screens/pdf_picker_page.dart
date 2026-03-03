import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:projects/services/app_feedback_service.dart';
import 'package:projects/widgets/app_page_route.dart';
import 'pdf_view_page.dart';

/// Lets the user pick a PDF then navigates to PdfViewPage
/// where they can preview it and tap Process to send to FastAPI.
class PdfPickerPage extends StatelessWidget {
  const PdfPickerPage({super.key});

  Future<void> _pickPdf(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.single.path == null) return;
    if (!context.mounted) return;
    AppFeedbackService.instance.playTick();

    Navigator.push(
      context,
      AppPageRoute.slideLeft(page: PdfViewPage(pdfPath: result.files.single.path!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Pick Sheet Music'),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note, size: 64, color: Color(0xFF4CAF50)),
            const SizedBox(height: 24),
            const Text(
              'Upload your guitar sheet music',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Supported format: PDF',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Pick PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: () => _pickPdf(context),
            ),
          ],
        ),
      ),
    );
  }
}