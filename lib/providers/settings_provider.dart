import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';

// ── Settings State ──────────────────────────────────────────────────────────

class SettingsState {
  final String streamingQuality; // 'automatic', 'low', 'normal', 'high'
  final String downloadQuality;
  final int crossfadeDuration; // 0-12 seconds
  final bool dataSaverMode;
  final Color accentColor;

  const SettingsState({
    this.streamingQuality = 'high',
    this.downloadQuality = 'high',
    this.crossfadeDuration = 9,
    this.dataSaverMode = false,
    this.accentColor = const Color(0xFF865AA4),
  });

  SettingsState copyWith({
    String? streamingQuality,
    String? downloadQuality,
    int? crossfadeDuration,
    bool? dataSaverMode,
    Color? accentColor,
  }) {
    return SettingsState(
      streamingQuality: streamingQuality ?? this.streamingQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      dataSaverMode: dataSaverMode ?? this.dataSaverMode,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}

// ── Settings Provider ───────────────────────────────────────────────────────

/// Settings stored entirely in SharedPreferences — no backend required.
/// Each setting is saved immediately on change and restored on app launch.
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    // Load from disk asynchronously after first build
    Future.microtask(_loadFromDisk);
    return const SettingsState();
  }

  // ── Load ──

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      streamingQuality: _toFrontend(prefs.getString('pulse_streaming_quality') ?? 'high'),
      downloadQuality: _toFrontend(prefs.getString('pulse_download_quality') ?? 'high'),
      crossfadeDuration: prefs.getInt('pulse_crossfade') ?? 9,
      dataSaverMode: prefs.getBool('pulse_data_saver') ?? false,
      accentColor: Color(prefs.getInt('pulse_accent_color_int') ?? 0xFF865AA4),
    );
  }

  // ── Setters (each saves immediately) ──

  void setStreamingQuality(String quality) {
    state = state.copyWith(streamingQuality: quality);
    _save();
  }

  void setDownloadQuality(String quality) {
    state = state.copyWith(downloadQuality: quality);
    _save();
  }

  void setCrossfade(int seconds) {
    state = state.copyWith(crossfadeDuration: seconds.clamp(0, 12));
    _save();
  }

  void setDataSaver(bool enabled) {
    state = state.copyWith(dataSaverMode: enabled);
    _save();
  }

  void setAccentColor(Color color, {bool syncToFirestore = true}) {
    state = state.copyWith(accentColor: color);
    _save(syncToFirestore: syncToFirestore);
  }

  // ── Persist ──

  Future<void> _save({bool syncToFirestore = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pulse_streaming_quality', _toBackend(state.streamingQuality));
    await prefs.setString('pulse_download_quality', _toBackend(state.downloadQuality));
    await prefs.setInt('pulse_crossfade', state.crossfadeDuration);
    await prefs.setBool('pulse_data_saver', state.dataSaverMode);
    await prefs.setInt('pulse_accent_color_int', state.accentColor.toARGB32());

    if (syncToFirestore) {
      final authState = ref.read(authProvider);
      if (authState.user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(authState.user!.uid)
              .update({
            'accentColorInt': state.accentColor.toARGB32(),
          });
        } catch (e) {
          debugPrint('Failed to sync accent color to Firestore: $e');
        }
      }
    }
  }

  // ── Quality string mapping ──

  static String _toBackend(String q) => switch (q) {
    'automatic' => 'auto',
    'normal' => 'medium',
    _ => q,
  };

  static String _toFrontend(String q) => switch (q) {
    'auto' => 'automatic',
    'medium' => 'normal',
    _ => q,
  };
}

// ── Provider Registration ───────────────────────────────────────────────────

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
