import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  StreamSubscription<List<int>>? _streamSubscription;

  /// Initialize and request microphone permission
  Future<bool> init() async {
    final status = await Permission.microphone.request();

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      // User permanently denied - need to open settings
      await openAppSettings();
      return false;
    }

    return false;
  }

  /// Start recording and stream audio chunks
  Future<void> startRecording({
    required Function(Uint8List) onAudioChunk,
  }) async {
    if (_isRecording) return;

    // Check permission again
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    _isRecording = true;

    // Configure for pitch detection
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,  // Raw 16-bit PCM
      numChannels: 1,                   // Mono
      sampleRate: 22050,                // Good for guitar range
    );

    // Start streaming audio
    final stream = await _recorder.startStream(config);

    _streamSubscription = stream.listen(
          (data) {
        if (_isRecording && data.isNotEmpty) {
          onAudioChunk(Uint8List.fromList(data));
        }
      },
      onError: (error) {
        print('❌ Recording error: $error');
        _isRecording = false;
      },
      onDone: () {
        print('🎤 Recording stream closed');
        _isRecording = false;
      },
    );
  }

  /// Stop recording
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    _isRecording = false;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await _recorder.stop();
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await stopRecording();
    await _recorder.dispose();
  }

  bool get isRecording => _isRecording;
}