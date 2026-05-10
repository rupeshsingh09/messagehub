import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  AudioRecorder? _audioRecorder;
  bool _isRecording = false;
  String? _lastRecordingPath;

  bool get isRecording => _isRecording;
  String? get lastRecordingPath => _lastRecordingPath;

  // ─── Permission ─────────────────────────────────────────────────────────────
  Future<bool> _requestPermission() async {
    // Explicitly request via permission_handler for Android
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      print('[AudioService] ❌ Microphone permission permanently denied');
      await openAppSettings();
    } else {
      print('[AudioService] ❌ Microphone permission denied (status: $status)');
    }
    return false;
  }

  // ─── Start Recording ─────────────────────────────────────────────────────────
  Future<bool> startRecording() async {
    try {
      // If already recording, stop it first to prevent leaks
      if (_isRecording) {
        print('[AudioService] ⚠️ Already recording — stopping previous session first');
        await stopRecording();
      }

      final hasPermission = await _requestPermission();
      if (!hasPermission) return false;

      // Dispose previous recorder if it exists
      await _audioRecorder?.dispose();
      _audioRecorder = AudioRecorder();

      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder!.start(config, path: path);
      _isRecording = true;
      _lastRecordingPath = path;

      print('[AudioService] ✅ Recording started: $path');
      return true;
    } catch (e) {
      print('[AudioService] ❌ Error starting recording: $e');
      _isRecording = false;
      _lastRecordingPath = null;
      return false;
    }
  }

  // ─── Stop Recording ──────────────────────────────────────────────────────────
  Future<String?> stopRecording() async {
    if (!_isRecording || _audioRecorder == null) {
      print('[AudioService] ⚠️ stopRecording called but not recording');
      _isRecording = false;
      return null;
    }

    try {
      // record v6: stop() returns the path on Android/iOS
      String? stoppedPath = await _audioRecorder!.stop();
      _isRecording = false;

      // Fallback: use the path we saved at start (record v6 may return null)
      final path = (stoppedPath != null && stoppedPath.isNotEmpty)
          ? stoppedPath
          : _lastRecordingPath;

      print('[AudioService] 🛑 Recording stopped. Returned path: $stoppedPath | Resolved path: $path');

      if (path == null) {
        print('[AudioService] ❌ No valid path after stop');
        return null;
      }

      // Validate the file exists and is not empty
      final file = File(path);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;

      print('[AudioService] 📁 File exists: $exists | Size: $size bytes');

      if (!exists || size == 0) {
        print('[AudioService] ❌ Audio file is empty or missing. Discarding.');
        return null;
      }

      return path;
    } catch (e) {
      print('[AudioService] ❌ Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  // ─── Dispose ─────────────────────────────────────────────────────────────────
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await _audioRecorder?.stop();
      }
      await _audioRecorder?.dispose();
      _audioRecorder = null;
      _isRecording = false;
    } catch (e) {
      print('[AudioService] ⚠️ Error during dispose: $e');
    }
  }
}
