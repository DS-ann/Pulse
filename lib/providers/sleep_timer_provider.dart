import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_provider.dart';

class SleepTimerState {
  final DateTime? expiresAt;
  final Duration? pausedRemaining;
  final Duration totalDuration;
  final bool isActive;
  final bool isPaused;
  final bool isExpired;

  SleepTimerState({
    this.expiresAt,
    this.pausedRemaining,
    this.totalDuration = Duration.zero,
    this.isActive = false,
    this.isPaused = false,
    this.isExpired = false,
  });

  Duration get remaining {
    if (isPaused && pausedRemaining != null) return pausedRemaining!;
    if (expiresAt == null) return Duration.zero;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  SleepTimerState copyWith({
    DateTime? expiresAt,
    Duration? pausedRemaining,
    Duration? totalDuration,
    bool? isActive,
    bool? isPaused,
    bool? isExpired,
  }) {
    return SleepTimerState(
      expiresAt: expiresAt ?? this.expiresAt,
      pausedRemaining: pausedRemaining ?? this.pausedRemaining,
      totalDuration: totalDuration ?? this.totalDuration,
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      isExpired: isExpired ?? this.isExpired,
    );
  }
}

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  Timer? _timer;
  int _timerId = 0;
  
  static const _keyExpiresAt = 'sleepTimer_expiresAt';
  static const _keyTotalDuration = 'sleepTimer_totalDuration';
  static const _keyIsPaused = 'sleepTimer_isPaused';
  static const _keyPausedRemaining = 'sleepTimer_pausedRemaining';
  
  @override
  SleepTimerState build() {
    _init();
    return SleepTimerState();
  }
  
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAtMillis = prefs.getInt(_keyExpiresAt);
    final totalDurationMillis = prefs.getInt(_keyTotalDuration);
    final isPaused = prefs.getBool(_keyIsPaused) ?? false;
    final pausedRemainingMillis = prefs.getInt(_keyPausedRemaining);
    
    if (expiresAtMillis != null && totalDurationMillis != null) {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMillis);
      final totalDuration = Duration(milliseconds: totalDurationMillis);
      final pausedRemaining = pausedRemainingMillis != null ? Duration(milliseconds: pausedRemainingMillis) : null;
      
      if (expiresAt.isAfter(DateTime.now()) || isPaused) {
        state = SleepTimerState(
          expiresAt: expiresAt,
          pausedRemaining: pausedRemaining,
          totalDuration: totalDuration,
          isActive: true,
          isPaused: isPaused,
        );
        _startPeriodicTimer();
      } else {
        // Expired while app was closed
        state = SleepTimerState(isExpired: true);
        _clearPrefs();
      }
    }
  }

  void startTimer(Duration duration) async {
    _timer?.cancel();
    final expiresAt = DateTime.now().add(duration);
    
    state = SleepTimerState(expiresAt: expiresAt, totalDuration: duration, isActive: true);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyExpiresAt, expiresAt.millisecondsSinceEpoch);
    await prefs.setInt(_keyTotalDuration, duration.inMilliseconds);
    await prefs.setBool(_keyIsPaused, false);
    await prefs.remove(_keyPausedRemaining);
    
    _startPeriodicTimer();
  }
  
  void _startPeriodicTimer() {
    _timer?.cancel();
    final currentId = DateTime.now().millisecondsSinceEpoch;
    _timerId = currentId;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_timerId != currentId) return;
      if (state.isPaused) return;
      
      if (state.remaining.inSeconds <= 0) {
        cancelTimer(expired: true);
        ref.read(audioProvider.notifier).pause();
      } else {
        // Trigger rebuild to update UI
        state = state.copyWith();
      }
    });
  }

  void togglePause() async {
    if (!state.isActive || state.expiresAt == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final newIsPaused = !state.isPaused;
    
    if (newIsPaused) {
      // Pausing: save exactly how much time is left and nullify expiresAt to freeze time
      final currentRemaining = state.remaining;
      state = state.copyWith(isPaused: true, pausedRemaining: currentRemaining);
      await prefs.setInt(_keyPausedRemaining, currentRemaining.inMilliseconds);
      await prefs.setBool(_keyIsPaused, true);
    } else {
      // Resuming: calculate a brand new expiresAt starting from right NOW
      if (state.pausedRemaining != null) {
        final newExpiresAt = DateTime.now().add(state.pausedRemaining!);
        state = state.copyWith(isPaused: false, expiresAt: newExpiresAt, pausedRemaining: null);
        await prefs.setInt(_keyExpiresAt, newExpiresAt.millisecondsSinceEpoch);
      } else {
        state = state.copyWith(isPaused: false);
      }
      await prefs.setBool(_keyIsPaused, false);
      await prefs.remove(_keyPausedRemaining);
    }
  }

  void cancelTimer({bool expired = false}) {
    _timer?.cancel();
    _timer = null;
    _timerId++; // Invalidate any pending callbacks
    state = SleepTimerState(isExpired: expired);
    _clearPrefs();
  }
  
  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyExpiresAt);
    await prefs.remove(_keyTotalDuration);
    await prefs.remove(_keyIsPaused);
    await prefs.remove(_keyPausedRemaining);
  }
  
  void clearExpired() {
    if (state.isExpired) {
        state = state.copyWith(isExpired: false);
    }
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, SleepTimerState>(() {
  return SleepTimerNotifier();
});
