import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:pulse/services/shazam_api.dart';
import 'package:pulse/src/rust/api/simple.dart';

class ShazamService {
  final _audioRecorder = AudioRecorder();
  bool _isCancelled = false;

  void cancel() {
    _isCancelled = true;
    _audioRecorder.stop();
  }

  Future<Map<String, dynamic>?> recognizeNearbySong() async {
    _isCancelled = false;
    try {
      // 1. Check Permissions
      if (!await _audioRecorder.hasPermission()) {
        throw Exception('Microphone permission not granted');
      }

      // 2. Prepare temporary file
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/shazam_record.wav';

      Map<String, dynamic>? lastResult;

      for (int attempt = 1; attempt <= 3; attempt++) {
        print('Listening to nearby song for 5 seconds (Attempt $attempt of 3)...');

        if (_isCancelled) break;

        // 3. Start recording 16kHz Mono WAV
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: path,
        );

        // 4. Record for 5 seconds, checking for cancellation
        for (int i = 0; i < 5; i++) {
          if (_isCancelled) break;
          await Future.delayed(const Duration(seconds: 1));
        }
        
        await _audioRecorder.stop();
        
        if (_isCancelled) break;

        // 5. Read the WAV bytes
        final file = File(path);
        if (!await file.exists()) {
          throw Exception('Recording failed, file not found');
        }

        final audioBytes = await file.readAsBytes();
        print(
          'Recorded ${audioBytes.length} bytes of audio data. Generating signature via Rust engine...',
        );

        try {
          // 6. Generate Signature via Native Rust Bridge
          final signatureUri = await generateSignature(audioBytes: audioBytes);
          print('Successfully generated Shazam Signature!');

          // 7. Request recognition from Shazam API
          print('Sending signature to Shazam...');
          if (_isCancelled) break;
          
          lastResult = await ShazamApi.recognizeSong(signatureUri);

          // If we found a track, clean up and return early!
          if (lastResult != null && lastResult['track'] != null) {
            await file.delete();
            return lastResult;
          }
        } catch (e) {
          print('Attempt $attempt failed: $e');
        }

        // Clean up temp file before next loop
        if (await file.exists()) {
          await file.delete();
        }
      }

      // If we got here, all 3 attempts failed to find a track
      return lastResult;
    } catch (e) {
      throw Exception('Shazam Recognition Failed: $e');
    }
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
