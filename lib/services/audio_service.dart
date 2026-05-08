import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  String? _lastRecordingPath;

  bool get isRecording => _isRecording;
  String? get lastRecordingPath => _lastRecordingPath;

  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        const config = RecordConfig();
        
        await _audioRecorder.start(config, path: path);
        _isRecording = true;
        _lastRecordingPath = path;
        print('[AudioService] Recording started: $path');
      }
    } catch (e) {
      print('[AudioService] Error starting recording: $e');
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      print('[AudioService] Recording stopped: $path');
      return path;
    } catch (e) {
      print('[AudioService] Error stopping recording: $e');
      return null;
    }
  }

  Future<void> playAudio(String url) async {
    await _audioPlayer.play(UrlSource(url));
  }

  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
  }

  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }
}
