import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Settings State ──────────────────────────────────────────────────────────

class SettingsState {
  final String streamingQuality; // 'automatic', 'low', 'normal', 'high'
  final String downloadQuality;
  final int crossfadeDuration; // 0-12 seconds
  final bool dataSaverMode;
  final Color accentColor;

  // ── Equalizer Settings ──
  final bool equalizerEnabled;
  final String equalizerPreset;
  final List<double> equalizerGains;
  final List<double> equalizerCustomGains;

  // ── Locale ──
  final String? appLocale; // e.g. 'en', 'hi', null means 'System'

  const SettingsState({
    this.streamingQuality = 'high',
    this.downloadQuality = 'high',
    this.crossfadeDuration = 9,
    this.dataSaverMode = false,
    this.accentColor = const Color(0xFF865AA4),
    this.equalizerEnabled = false,
    this.equalizerPreset = 'Custom',
    this.equalizerGains = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    this.equalizerCustomGains = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    this.appLocale,
  });

  SettingsState copyWith({
    String? streamingQuality,
    String? downloadQuality,
    int? crossfadeDuration,
    bool? dataSaverMode,
    Color? accentColor,
    bool? equalizerEnabled,
    String? equalizerPreset,
    List<double>? equalizerGains,
    List<double>? equalizerCustomGains,
    String? appLocale,
    bool clearLocale = false, // Helper to unset the locale
  }) {
    return SettingsState(
      streamingQuality: streamingQuality ?? this.streamingQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      dataSaverMode: dataSaverMode ?? this.dataSaverMode,
      accentColor: accentColor ?? this.accentColor,
      equalizerEnabled: equalizerEnabled ?? this.equalizerEnabled,
      equalizerPreset: equalizerPreset ?? this.equalizerPreset,
      equalizerGains: equalizerGains ?? this.equalizerGains,
      equalizerCustomGains: equalizerCustomGains ?? this.equalizerCustomGains,
      appLocale: clearLocale ? null : (appLocale ?? this.appLocale),
    );
  }
}

// ── Settings Provider ───────────────────────────────────────────────────────

class SettingsNotifier extends Notifier<SettingsState> {
  /// True once we have received real data from Firestore.
  /// Prevents the local disk-load from overwriting cloud data.
  bool _firestoreLoaded = false;

  /// Debounce timer for Firestore writes — prevents hammering the DB
  /// while the user is dragging a slider.
  Timer? _firestoreDebounce;

  @override
  SettingsState build() {
    ref.onDispose(() => _firestoreDebounce?.cancel());
    // Load from disk asynchronously. If Firestore data arrives first
    // (_firestoreLoaded == true), _loadFromDisk() will exit early.
    Future.microtask(_loadFromDisk);
    return const SettingsState();
  }

  // ── Load from local disk (SharedPreferences) ──

  Future<void> _loadFromDisk() async {
    // If Firestore already populated state, never overwrite with stale local data.
    if (_firestoreLoaded) return;

    final prefs = await SharedPreferences.getInstance();

    // Parse equalizer gains
    final gainsStr = prefs.getString('pulse_eq_gains');
    List<double> loadedGains = List.filled(10, 0.0);
    if (gainsStr != null && gainsStr.isNotEmpty) {
      try {
        final parts = gainsStr.split(',');
        for (int i = 0; i < parts.length && i < 10; i++) {
          loadedGains[i] = double.parse(parts[i]);
        }
      } catch (_) {}
    }

    final customGainsStr = prefs.getString('pulse_eq_custom_gains');
    List<double> loadedCustomGains = List.filled(10, 0.0);
    if (customGainsStr != null && customGainsStr.isNotEmpty) {
      try {
        final parts = customGainsStr.split(',');
        for (int i = 0; i < parts.length && i < 10; i++) {
          loadedCustomGains[i] = double.parse(parts[i]);
        }
      } catch (_) {}
    } else {
      loadedCustomGains = List<double>.from(loadedGains);
    }

    // Guard again: Firestore may have arrived while we were awaiting prefs.
    if (_firestoreLoaded) return;

    state = state.copyWith(
      streamingQuality: _toFrontend(prefs.getString('pulse_streaming_quality') ?? 'high'),
      downloadQuality: _toFrontend(prefs.getString('pulse_download_quality') ?? 'high'),
      crossfadeDuration: prefs.getInt('pulse_crossfade') ?? 9,
      dataSaverMode: prefs.getBool('pulse_data_saver') ?? false,
      accentColor: Color(prefs.getInt('pulse_accent_color_int') ?? 0xFF865AA4),
      equalizerEnabled: prefs.getBool('pulse_eq_enabled') ?? false,
      equalizerPreset: prefs.getString('pulse_eq_preset') ?? 'Custom',
      equalizerGains: loadedGains,
      equalizerCustomGains: loadedCustomGains,
      appLocale: prefs.getString('pulse_app_locale'),
    );
  }

  // ── Load from Firestore (called by auth_provider on login) ──

  /// Applies settings fetched from Firestore and locks out the disk loader.
  /// Supports both current and legacy field names transparently.
  void updateFromBackend(Map<String, dynamic> data) {
    // Mark Firestore as loaded FIRST — prevents _loadFromDisk from overwriting.
    _firestoreLoaded = true;

    // Parse equalizer gains — support both old and new field names
    List<double>? parsedGains;
    final rawGains = data['equalizerGains'] ?? data['eqCustomGains'] ?? data['eqGains'];
    if (rawGains != null) {
      try {
        final list = rawGains as List;
        parsedGains = list.map((e) => (e as num).toDouble()).toList();
        // Pad or trim to exactly 10 bands
        while (parsedGains.length < 10) { parsedGains.add(0.0); }
        if (parsedGains.length > 10) parsedGains = parsedGains.sublist(0, 10);
      } catch (_) {}
    }

    List<double>? parsedCustomGains;
    final rawCustomGains = data['equalizerCustomGains'];
    if (rawCustomGains != null) {
      try {
        final list = rawCustomGains as List;
        parsedCustomGains = list.map((e) => (e as num).toDouble()).toList();
        while (parsedCustomGains.length < 10) { parsedCustomGains.add(0.0); }
        if (parsedCustomGains.length > 10) parsedCustomGains = parsedCustomGains.sublist(0, 10);
      } catch (_) {}
    }

    // Support both old and new field names
    final eqEnabled = data['equalizerEnabled'] ?? data['eqEnabled'];
    final eqPreset  = data['equalizerPreset']  ?? data['eqPreset'];

    // Resolve accent color — new format: accentColorInt (int)
    //                        old format: accentColor (hex string e.g. "#865AA4")
    Color? resolvedAccentColor;
    if (data['accentColorInt'] != null) {
      resolvedAccentColor = Color(data['accentColorInt'] as int);
    } else if (data['accentColor'] is String) {
      try {
        final hex = (data['accentColor'] as String).replaceFirst('#', '');
        resolvedAccentColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    state = state.copyWith(
      streamingQuality: data['streamingQuality'] != null ? _toFrontend(data['streamingQuality'] as String) : null,
      downloadQuality:  data['downloadQuality']  != null ? _toFrontend(data['downloadQuality']  as String) : null,
      crossfadeDuration: (data['crossfadeDuration'] as num?)?.toInt(),
      dataSaverMode:    data['dataSaverMode'] as bool?,
      accentColor:      resolvedAccentColor,
      equalizerEnabled: eqEnabled as bool?,
      equalizerPreset:  eqPreset  as String?,
      equalizerGains:   parsedGains,
      equalizerCustomGains: parsedCustomGains,
      appLocale:        data['appLocale'] as String?,
    );

    // Persist locally so the app works offline on subsequent launches.
    // No Firestore write — data came FROM Firestore.
    _persistToDisk();
  }

  /// Called when the auth provider determines there is NO cloud data yet (new user).
  /// Unlocks local changes so they can be written up to Firestore.
  void markFirestoreLoaded() {
    _firestoreLoaded = true;
    _scheduleFsWrite(); // Push current defaults to the cloud immediately
  }

  /// Called when the Firestore settings fetch fails (network error, permission error, etc.).
  /// Ensures the disk cache is still applied instead of the app showing default/stale settings.
  /// Does NOT write to Firestore — that's only done after a successful cloud round-trip.
  Future<void> loadFromDiskFallback() async {
    // Only run if Firestore hasn't successfully loaded yet in this session.
    if (!_firestoreLoaded) {
      await _loadFromDisk();
    }
  }

  // ── Setters ──

  void setStreamingQuality(String quality) {
    state = state.copyWith(streamingQuality: quality);
    _persistToDisk();
    _scheduleFsWrite();
  }

  void setDownloadQuality(String quality) {
    state = state.copyWith(downloadQuality: quality);
    _persistToDisk();
    _scheduleFsWrite();
  }

  void setCrossfade(int seconds, {bool syncToFirestore = true}) {
    state = state.copyWith(crossfadeDuration: seconds.clamp(0, 12));
    _persistToDisk();
    if (syncToFirestore) _scheduleFsWrite();
  }

  void setDataSaver(bool enabled) {
    state = state.copyWith(dataSaverMode: enabled);
    _persistToDisk();
    _scheduleFsWrite();
  }

  void setAccentColor(Color color, {bool syncToFirestore = true}) {
    state = state.copyWith(accentColor: color);
    _persistToDisk();
    if (syncToFirestore) _scheduleFsWrite();
  }

  void setEqualizerEnabled(bool enabled) {
    state = state.copyWith(equalizerEnabled: enabled);
    _persistToDisk();
    _scheduleFsWrite();
  }

  void setEqualizerPreset(String preset) {
    state = state.copyWith(equalizerPreset: preset);
    _persistToDisk();
    _scheduleFsWrite();
  }

  void setEqualizerGains(List<double> gains, {bool syncToFirestore = true}) {
    final list = List<double>.from(gains);
    state = state.copyWith(
      equalizerGains: list,
      equalizerCustomGains: state.equalizerPreset == 'Custom' ? list : null,
    );
    _persistToDisk();
    if (syncToFirestore) _scheduleFsWrite();
  }


  /// Apply a named preset atomically: updates preset name, gains, and pre-amp
  /// in a single state change, triggering exactly one disk write and one
  /// debounced Firestore write (instead of three separate writes).
  void setEqualizerPresetWithValues(String preset, List<double> gains) {
    state = state.copyWith(
      equalizerPreset: preset,
      equalizerGains: List<double>.from(gains),
      equalizerCustomGains: preset == 'Custom' ? List<double>.from(gains) : null,
    );
    _persistToDisk();
    _scheduleFsWrite();
  }

  void setAppLocale(String? locale) {
    state = state.copyWith(appLocale: locale, clearLocale: locale == null);
    _persistToDisk();
    _scheduleFsWrite();
  }

  // ── Persist to SharedPreferences (always immediate, always offline-safe) ──

  Future<void> _persistToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pulse_streaming_quality', _toBackend(state.streamingQuality));
    await prefs.setString('pulse_download_quality',  _toBackend(state.downloadQuality));
    await prefs.setInt('pulse_crossfade',            state.crossfadeDuration);
    await prefs.setBool('pulse_data_saver',          state.dataSaverMode);
    await prefs.setInt('pulse_accent_color_int',     state.accentColor.toARGB32());
    await prefs.setBool('pulse_eq_enabled',          state.equalizerEnabled);
    await prefs.setString('pulse_eq_preset',         state.equalizerPreset);
    await prefs.setString('pulse_eq_gains',          state.equalizerGains.join(','));
    await prefs.setString('pulse_eq_custom_gains',   state.equalizerCustomGains.join(','));
    
    if (state.appLocale == null) {
      await prefs.remove('pulse_app_locale');
    } else {
      await prefs.setString('pulse_app_locale', state.appLocale!);
    }
  }

  // ── Debounced Firestore write ──
  // Waits 1 second after the last change before writing to Firestore.
  // Prevents hammering the DB while the user drags a slider.

  void _scheduleFsWrite() {
    _firestoreDebounce?.cancel();
    _firestoreDebounce = Timer(const Duration(seconds: 1), _writeToFirestore);
  }

  Future<void> _writeToFirestore() async {
    // Use FirebaseAuth directly — never rely on ref.read(authProvider).user
    // which can be transiently null during startup race conditions.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('preferences')
          .set({
        'accentColorInt':        state.accentColor.toARGB32(),
        'streamingQuality':      _toBackend(state.streamingQuality),
        'downloadQuality':       _toBackend(state.downloadQuality),
        'crossfadeDuration':     state.crossfadeDuration,
        'dataSaverMode':         state.dataSaverMode,
        'equalizerEnabled':      state.equalizerEnabled,
        'equalizerPreset':       state.equalizerPreset,
        'equalizerGains':        state.equalizerGains,
        'equalizerCustomGains':  state.equalizerCustomGains,
        'appLocale':             state.appLocale,
        // Purge legacy ghost fields from the database
        'equalizerPreAmp':       FieldValue.delete(),
        'equalizerCustomPreAmp': FieldValue.delete(),
        'eqPreAmp':              FieldValue.delete(),
        'eqCustomPreAmp':        FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Settings] Firestore write failed: $e');
    }
  }

  // ── Quality string mapping ──

  static String _toBackend(String q) => switch (q) {
    'automatic' => 'auto',
    'normal'    => 'medium',
    _           => q,
  };

  static String _toFrontend(String q) => switch (q) {
    'auto'   => 'automatic',
    'medium' => 'normal',
    _        => q,
  };
}

// ── Provider Registration ───────────────────────────────────────────────────

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
