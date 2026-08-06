import 'package:wakelock_plus/wakelock_plus.dart';

class WakelockManager {
  static final WakelockManager _instance = WakelockManager._internal();
  factory WakelockManager() => _instance;
  WakelockManager._internal();

  bool _isPlaying = false;
  bool _isDownloading = false;

  void setPlaying(bool playing) {
    if (_isPlaying == playing) return;
    _isPlaying = playing;
    _updateWakelock();
  }

  void setDownloading(bool downloading) {
    if (_isDownloading == downloading) return;
    _isDownloading = downloading;
    _updateWakelock();
  }

  Future<void> disableAll() async {
    _isPlaying = false;
    _isDownloading = false;
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  Future<void> _updateWakelock() async {
    try {
      if (_isPlaying || _isDownloading) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }
}
