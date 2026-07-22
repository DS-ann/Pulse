import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../providers/audio_provider.dart';
import '../../../core/theme/app_colors.dart';

class EqualizerSheet extends ConsumerStatefulWidget {
  const EqualizerSheet({super.key});

  @override
  ConsumerState<EqualizerSheet> createState() => _EqualizerSheetState();
}

List<double>? _cachedGains;
String _globalActivePreset = 'Custom';

class _EqualizerSheetState extends ConsumerState<EqualizerSheet> {
  AndroidEqualizer? _equalizer;
  late String _activePreset;

  final Map<String, List<double>> _presets = {
    // ── Standard ──
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Perfect': [1.0, 0.6, 0.3, 0.0, -0.4, -0.4, 0.0, 0.3, 0.8, 1.0],
    
    // ── Genre-Based ──
    'Acoustic': [0.5, 0.5, 0.4, 0.2, 0.2, 0.2, 0.4, 0.5, 0.4, 0.3],
    'Classical': [0.6, 0.5, 0.4, 0.3, -0.2, -0.2, 0.0, 0.4, 0.6, 0.8],
    'Dance': [0.8, 0.6, 0.2, 0.0, -0.2, -0.4, 0.0, 0.2, 0.6, 0.8],
    'Electronic': [0.8, 0.7, 0.3, 0.0, -0.4, -0.5, 0.1, 0.4, 0.7, 0.9],
    'Hip-Hop': [0.9, 0.7, 0.3, 0.1, -0.2, -0.2, 0.1, 0.2, 0.4, 0.6],
    'Jazz': [0.5, 0.4, 0.2, 0.3, -0.2, -0.2, 0.0, 0.2, 0.4, 0.6],
    'Latin': [0.6, 0.4, 0.0, 0.0, -0.2, -0.2, 0.0, 0.0, 0.4, 0.6],
    'Pop': [-0.2, 0.2, 0.5, 0.8, 0.4, -0.2, -0.4, -0.2, 0.2, 0.4],
    'R&B': [0.6, 0.8, 0.4, 0.1, -0.2, -0.1, 0.2, 0.4, 0.5, 0.6],
    'Rock': [0.8, 0.5, -0.2, -0.4, 0.0, 0.3, 0.7, 1.0, 0.8, 0.5],

    // ── Audio-Enhancement ──
    'Bass Booster': [1.0, 0.8, 0.6, 0.4, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Reducer': [-1.0, -0.8, -0.6, -0.4, -0.1, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Treble Booster': [0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.4, 0.6, 0.8, 1.0],
    'Treble Reducer': [0.0, 0.0, 0.0, 0.0, 0.0, -0.1, -0.4, -0.6, -0.8, -1.0],
    'Vocal Booster': [-0.2, -0.4, -0.4, 0.2, 0.6, 0.8, 0.6, 0.2, -0.4, -0.4],
    'Piano': [0.4, 0.2, 0.0, 0.3, 0.4, 0.3, 0.5, 0.6, 0.4, 0.2],
    'Small Speakers': [0.8, 0.6, 0.4, -0.2, -0.6, -0.8, -0.6, -0.2, 0.4, 0.6],
  };

  void _applyPreset(String presetName, AndroidEqualizerParameters params) {
    if (presetName == 'Custom') return;
    setState(() {
      _activePreset = presetName;
      _globalActivePreset = presetName;
    });
    
    final values = _presets[presetName]!;
    for (int i = 0; i < params.bands.length; i++) {
      // Map 10-band preset to actual device bands (usually 5 or 10)
      int presetIndex = params.bands.length <= 1 ? 0 : (i * (values.length - 1)) ~/ (params.bands.length - 1);
      double proportion = values[presetIndex];
      
      // Scale based on device limits to preserve the true curve shape
      double val = proportion > 0 
          ? proportion * params.maxDecibels 
          : proportion * params.minDecibels.abs();
          
      val = val.clamp(params.minDecibels, params.maxDecibels);
      params.bands[i].setGain(val);
    }
  }

  @override
  void initState() {
    super.initState();
    _activePreset = _globalActivePreset;
    // In just_audio, AndroidEqualizer is supported mainly on Android.
    if (Platform.isAndroid) {
      _equalizer = ref.read(audioHandlerProvider).equalizer;
    }
  }

  String _formatFrequency(double hz) {
    if (hz >= 1000) {
      return '${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)}k';
    }
    return '${hz.round()}';
  }

  @override
  Widget build(BuildContext context) {
    if (_equalizer == null) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(
          child: Text('Equalizer is only supported on Android', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return FutureBuilder<AndroidEqualizerParameters>(
      future: _equalizer!.parameters,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
        }

        final params = snapshot.data!;
        
        return Container(
          height: 450,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Equalizer',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    StreamBuilder<bool>(
                      stream: _equalizer!.enabledStream,
                      builder: (context, enabledSnapshot) {
                        final isEnabled = enabledSnapshot.data ?? false;
                        return Switch(
                          value: isEnabled,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (value) async {
                            await _equalizer!.setEnabled(value);
                            final params = await _equalizer!.parameters;
                            if (!value) {
                              // Disabled: Save current gains and flatten
                              _cachedGains = params.bands.map((b) => b.gain).toList();
                              for (var band in params.bands) {
                                band.setGain(0.0);
                              }
                            } else {
                              // Enabled: Restore gains
                              if (_cachedGains != null && _cachedGains!.length == params.bands.length) {
                                for (int i = 0; i < params.bands.length; i++) {
                                  params.bands[i].setGain(_cachedGains![i]);
                                }
                              }
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.glassBorder, height: 1),

              // ── Presets ──
              StreamBuilder<bool>(
                stream: _equalizer!.enabledStream,
                builder: (context, enabledSnapshot) {
                  final isEnabled = enabledSnapshot.data ?? false;
                  return Opacity(
                    opacity: isEnabled ? 1.0 : 0.5,
                    child: IgnorePointer(
                      ignoring: !isEnabled,
                      child: SizedBox(
                        height: 50,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          children: [
                            'Custom',
                            ..._presets.keys,
                          ].map((preset) {
                            final isActive = _activePreset == preset;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ActionChip(
                                label: Text(preset, style: TextStyle(fontSize: 12, color: isActive ? Theme.of(context).colorScheme.primary : AppColors.textSecondary)),
                                backgroundColor: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : AppColors.surface,
                                side: BorderSide(color: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.5) : Colors.transparent),
                                onPressed: () => _applyPreset(preset, params),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                }
              ),
              const Divider(color: AppColors.glassBorder, height: 1),

              // ── Bands ──
              Expanded(
                child: StreamBuilder<bool>(
                  stream: _equalizer!.enabledStream,
                  builder: (context, enabledSnapshot) {
                    final isEnabled = enabledSnapshot.data ?? false;
                    return Opacity(
                      opacity: isEnabled ? 1.0 : 0.5,
                      child: IgnorePointer(
                        ignoring: !isEnabled,
                        child: Center(
                          child: ListView.builder(
                            shrinkWrap: true,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 24.0),
                            itemCount: params.bands.length,
                            itemBuilder: (context, index) {
                              final band = params.bands[index];
                              return _buildBandSlider(band, params);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBandSlider(AndroidEqualizerBand band, AndroidEqualizerParameters params) {
    return Container(
      width: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        children: [
          // DB Label
          StreamBuilder<double>(
            stream: band.gainStream,
            builder: (context, snapshot) {
              final gain = snapshot.data ?? 0.0;
              return Text(
                '${gain > 0 ? '+' : ''}${gain.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              );
            },
          ),
          const SizedBox(height: 12),
          // Slider
          Expanded(
            child: StreamBuilder<double>(
              stream: band.gainStream,
              builder: (context, snapshot) {
                final gain = snapshot.data ?? 0.0;
                return RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      inactiveTrackColor: AppColors.surface,
                      thumbColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: Slider(
                      value: gain,
                      min: params.minDecibels,
                      max: params.maxDecibels,
                      onChanged: (value) {
                        if (_activePreset != 'Custom') {
                          setState(() {
                            _activePreset = 'Custom';
                            _globalActivePreset = 'Custom';
                          });
                        }
                        band.setGain(value);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Frequency Label
          Text(
            _formatFrequency(band.centerFrequency),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
