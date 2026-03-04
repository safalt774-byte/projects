import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:projects/services/api_service.dart';

/// Settings page where the user can set and test the backend server URL.
/// This avoids having to edit code every time the tunnel URL changes.
class ServerSettingsPage extends StatefulWidget {
  const ServerSettingsPage({super.key});

  @override
  State<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends State<ServerSettingsPage> {
  late TextEditingController _urlController;
  bool _testing = false;
  bool? _reachable;
  late final VoidCallback _notifierListener;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiService.baseUrl);

    // Update the TextField if baseUrl changes elsewhere in the app
    _notifierListener = () {
      final current = ApiService.baseUrlNotifier.value;
      if (current != _urlController.text) {
        _urlController.text = current;
      }
    };
    ApiService.baseUrlNotifier.addListener(_notifierListener);
  }

  @override
  void dispose() {
    ApiService.baseUrlNotifier.removeListener(_notifierListener);
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Preview and possibly correct the URL before testing/saving
    final sanitized = ApiService.sanitizeUrl(url);

    // Detect a common typo and propose a correction (e.g. trycloudfare -> trycloudflare)
    String? typoCorrection;
    final lower = sanitized.toLowerCase();
    if (lower.contains('trycloudfare')) {
      typoCorrection = sanitized.replaceAll(RegExp('(?i)trycloudfare'), 'trycloudflare');
    }

    // If we have a typoCorrection, ask the user to accept it first
    String urlToTest = sanitized;
    if (typoCorrection != null && typoCorrection != sanitized) {
      final accept = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Did you mean:'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sanitized),
              const SizedBox(height: 8),
              const Text('Suggested correction:'),
              Text(typoCorrection!, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Use original')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Use suggestion')),
          ],
        ),
      );

      if (accept == true) {
        urlToTest = typoCorrection;
      }
    } else if (sanitized != url) {
      // If sanitized differs from what the user pasted (e.g. trimmed spaces / added https), show a preview and ask to continue
      final accept = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Preview server URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Original:'),
              Text(url),
              const SizedBox(height: 8),
              const Text('Sanitized (will be saved):'),
              Text(sanitized, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save sanitized')),
          ],
        ),
      );

      if (accept != true) return; // user canceled
    }

    setState(() { _testing = true; _reachable = null; });

    final ok = await ApiService.testConnection(urlToTest);

    if (!mounted) return;

    if (ok) {
      await ApiService.setBaseUrl(urlToTest);
      setState(() { _testing = false; _reachable = true; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Connected & saved!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } else {
      setState(() { _testing = false; _reachable = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Cannot reach server at "$urlToTest". Check the URL and try again.'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Server Settings'),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend Server URL',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste the Cloudflare Tunnel URL (or any tunnel URL) from your terminal here.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'https://xxx-xxx.trycloudflare.com',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF16213E),
                prefixIcon: Icon(
                  _reachable == null
                      ? Icons.link
                      : _reachable! ? Icons.check_circle : Icons.error,
                  color: _reachable == null
                      ? const Color(0xFF4CAF50)
                      : _reachable! ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                  size: 20,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A3A5E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _testing ? null : _testAndSave,
                icon: _testing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.wifi_tethering),
                label: Text(_testing ? 'Testing...' : 'Test & Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF4CAF50).withAlpha(128),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Current saved URL + actions
            ValueListenableBuilder<String>(
              valueListenable: ApiService.baseUrlNotifier,
              builder: (context, savedUrl, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A3A5E)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Saved server URL', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(savedUrl, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy URL',
                        icon: const Icon(Icons.copy, color: Colors.white70),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: savedUrl));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied URL to clipboard')));
                        },
                      ),
                      IconButton(
                        tooltip: 'Reset to default',
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Reset server URL?'),
                              content: const Text('This will reset the saved server URL to the built-in default.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reset')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ApiService.resetToDefault();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server URL reset to default')));
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How to get the URL:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('1. Start your backend server\n'
                       '2. Run: cloudflared tunnel --url http://localhost:8000\n'
                       '3. Copy the https://...trycloudflare.com URL\n'
                       '4. Paste it above and tap Test & Save',
                    style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

